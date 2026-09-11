const std = @import("std");

const wayland = @import("wayland");
const xkbcommon = @import("xkbcommon");
const river = wayland.client.river;

const config = @import("config.zig");
const layout = @import("layout.zig");
const types = @import("types.zig");

pub fn setupKeybindings(
    allocator: std.mem.Allocator,
    wm: *types.WindowManager,
) !void {
    const river_seat = wm.river_seat orelse {
        std.debug.print("Failed to find seat\n", .{});
        return;
    };
    const river_xkb_bindings = wm.river_xkb_bindings orelse {
        std.debug.print("Failed to find xkb bindings\n", .{});
        return;
    };

    for (wm.xkb_binding_list.items) |xkb_binding| {
        xkb_binding.river_xkb_binding.destroy();
    }
    wm.xkb_binding_list.clearRetainingCapacity();

    const keybindings = wm.config.keybindings orelse &config.default_keybindings;
    for (keybindings) |keybinding| {
        const keysym = parseKey(keybinding.key) orelse {
            std.debug.print("Failed to parse key '{s}'\n", .{keybinding.key});
            continue;
        };

        const river_xkb_binding = try river_xkb_bindings.getXkbBinding(
            river_seat,
            @intFromEnum(keysym),
            keybinding.modifiers,
        );

        try wm.xkb_binding_list.append(
            allocator,
            .{ .river_xkb_binding = river_xkb_binding, .action = keybinding.action },
        );

        river_xkb_binding.setListener(*types.WindowManager, xkbBindingListener, wm);
        river_xkb_binding.enable();
    }
}

fn parseKey(key: [:0]const u8) ?xkbcommon.Keysym {
    const keysym = xkbcommon.Keysym.fromName(key, .case_insensitive);
    if (keysym != .NoSymbol) return keysym;
    return null;
}

fn xkbBindingListener(
    xkb_binding: *river.XkbBindingV1,
    event: river.XkbBindingV1.Event,
    wm: *types.WindowManager,
) void {
    if (wm.task == .pointer_action) return;

    for (wm.xkb_binding_list.items) |binding| {
        if (binding.river_xkb_binding != xkb_binding) continue;

        switch (event) {
            .pressed => {
                keybindingPressed(
                    wm.allocator,
                    wm.io,
                    wm.environ_map,
                    binding.action,
                    wm,
                ) catch |err| {
                    std.debug.print("Keybinding's action failed: {}\n", .{err});
                };
            },
            else => {},
        }
        return;
    }
}

fn keybindingPressed(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: std.process.Environ.Map,
    action: types.KeybindingAction,
    wm: *types.WindowManager,
) !void {
    const output_idx = wm.focused_output_idx orelse return;
    const output = &wm.output_list.items[output_idx];

    const workspace_idx = output.focused_workspace_idx;
    const workspace = &output.workspace_list.items[workspace_idx];

    action_switch: switch (action) {
        .close_window => {
            const window_idx = workspace.focused_window_idx orelse return;
            const window = &workspace.window_list.items[window_idx];
            window.should_close = true;
        },
        .toggle_maximize => {
            const window_idx = workspace.focused_window_idx orelse return;
            var window = &workspace.window_list.items[window_idx];
            if (window.is_fullscreen) return;
            window.is_maximized = !window.is_maximized;
        },
        .toggle_fullscreen => {
            const window_idx = workspace.focused_window_idx orelse return;
            const window = &workspace.window_list.items[window_idx];
            window.is_fullscreen = !window.is_fullscreen;
        },
        .toggle_workspace_floating => workspace.is_floating = !workspace.is_floating,
        .adjust_window_width => |increment| {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            var window = &workspace.window_list.items[window_idx];
            if (window.is_fullscreen) return;

            var proportion = window.proportion;
            if (window.is_maximized) proportion = 1.0;

            const non_exclusive = output.non_exclusive orelse output.rect;
            const h_gap = wm.config.horizontal_gap;
            const base_width: f32 = @floatFromInt(non_exclusive.width - h_gap);
            const width_with_gap: i32 = @trunc(base_width * (proportion + increment));
            if (width_with_gap - h_gap < 2 * wm.config.border.width) return;

            window.is_maximized = false;
            window.proportion = proportion + increment;
        },
        .set_window_width => |proportion| {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            var window = &workspace.window_list.items[window_idx];
            if (window.is_fullscreen) return;

            window.is_maximized = false;
            window.proportion = proportion;
        },
        .exit => {
            wm.task = .exit;
            return;
        },
        .reload_config => {
            std.zon.parse.free(wm.allocator, wm.config);
            wm.config = config.load(allocator, io, environ_map);

            layout.update(wm.allocator, wm.output_list, wm.config);
            wm.task = .setup_seat;

            return;
        },
        .toggle_passthrough => {
            wm.is_passthrough = !wm.is_passthrough;
            wm.task = .toggle_passthrough;
            return;
        },
        .spawn => |command| {
            const pid = std.posix.system.fork();
            if (pid < 0) {
                return;
            } else if (pid == 0) {
                _ = try std.process.spawn(io, .{ .argv = command });
                std.process.exit(0);
            }
            _ = std.posix.system.waitpid(pid, null, 0);
            return;
        },
        .focus_window_left => {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == 0) return;
            workspace.focused_window_idx = window_idx - 1;
        },
        .focus_window_right => {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == workspace.window_list.items.len - 1) return;
            workspace.focused_window_idx = window_idx + 1;
        },
        .focus_window_or_output_left => {
            const window_idx = workspace.focused_window_idx orelse return;
            if (workspace.is_floating or window_idx == 0) {
                continue :action_switch .focus_output_left;
            }
            continue :action_switch .focus_window_left;
        },
        .focus_window_or_output_right => {
            const window_idx = workspace.focused_window_idx orelse return;
            if (workspace.is_floating or window_idx == workspace.window_list.items.len - 1) {
                continue :action_switch .focus_output_right;
            }
            continue :action_switch .focus_window_right;
        },
        .move_window_left => {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == 0) return;

            std.mem.swap(
                types.Window,
                &workspace.window_list.items[window_idx],
                &workspace.window_list.items[window_idx - 1],
            );
            workspace.focused_window_idx = window_idx - 1;
        },
        .move_window_right => {
            if (workspace.is_floating) return;
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == workspace.window_list.items.len - 1) return;

            std.mem.swap(
                types.Window,
                &workspace.window_list.items[window_idx],
                &workspace.window_list.items[window_idx + 1],
            );
            workspace.focused_window_idx = window_idx + 1;
        },
        .move_window_left_or_to_output_left => {
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == 0) {
                continue :action_switch .move_window_to_output_left;
            }
            continue :action_switch .move_window_left;
        },
        .move_window_right_or_to_output_right => {
            const window_idx = workspace.focused_window_idx orelse return;
            if (window_idx == workspace.window_list.items.len - 1) {
                continue :action_switch .move_window_to_output_right;
            }
            continue :action_switch .move_window_right;
        },
        .focus_workspace_above => {
            if (workspace_idx == 0) return;
            output.focused_workspace_idx -= 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_workspace_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) return;
            output.focused_workspace_idx += 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_workspace_or_output_above => {
            if (workspace_idx == 0) {
                continue :action_switch .focus_output_above;
            }
            continue :action_switch .focus_workspace_above;
        },
        .focus_workspace_or_output_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) {
                continue :action_switch .focus_output_below;
            }
            continue :action_switch .focus_workspace_below;
        },
        .focus_workspace_number => |number| {
            if (number == 0 or number > output.workspace_list.items.len) return;
            if (workspace_idx == number - 1) return;

            output.focused_workspace_idx = number - 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_workspace_previous => {
            const previous = wm.previous_workspace orelse return;

            const target_output = &wm.output_list.items[previous.output_idx];
            target_output.focused_workspace_idx = previous.workspace_idx;

            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_workspace_above => {
            if (workspace_idx == 0) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[workspace_idx - 1],
            );

            output.focused_workspace_idx = workspace_idx - 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_workspace_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[workspace_idx + 1],
            );

            output.focused_workspace_idx = workspace_idx + 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_workspace_or_output_above => {
            if (workspace_idx == 0) {
                continue :action_switch .move_window_to_output_above;
            }
            continue :action_switch .move_window_to_workspace_above;
        },
        .move_window_to_workspace_or_output_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) {
                continue :action_switch .move_window_to_output_below;
            }
            continue :action_switch .move_window_to_workspace_below;
        },
        .move_window_to_workspace_number => |number| {
            if (number == 0 or
                number > output.workspace_list.items.len or
                number - 1 == workspace_idx) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[number - 1],
            );

            output.focused_workspace_idx = number - 1;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .send_window_to_workspace_above => {
            if (workspace_idx == 0) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[workspace_idx - 1],
            );
        },
        .send_window_to_workspace_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[workspace_idx + 1],
            );
        },
        .send_window_to_workspace_or_output_above => {
            if (workspace_idx == 0) {
                continue :action_switch .send_window_to_output_above;
            }
            continue :action_switch .send_window_to_workspace_above;
        },
        .send_window_to_workspace_or_output_below => {
            if (workspace_idx == output.workspace_list.items.len - 1) {
                continue :action_switch .send_window_to_output_below;
            }
            continue :action_switch .send_window_to_workspace_below;
        },
        .send_window_to_workspace_number => |number| {
            if (number == 0 or
                number > output.workspace_list.items.len or
                number - 1 == workspace_idx) return;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &output.workspace_list.items[number - 1],
            );
        },
        .focus_output_left => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .left,
            ) orelse return;

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_output_right => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .right,
            ) orelse return;

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_output_above => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .above,
            ) orelse return;

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .focus_output_below => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .below,
            ) orelse return;

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_output_left => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .left,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_output_right => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .right,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_output_above => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .above,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .move_window_to_output_below => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .below,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );

            wm.focused_output_idx = target_output_idx;
            wm.previous_workspace = .{
                .output_idx = output_idx,
                .workspace_idx = workspace_idx,
            };
        },
        .send_window_to_output_left => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .left,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );
        },
        .send_window_to_output_right => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .right,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );
        },
        .send_window_to_output_above => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .above,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );
        },
        .send_window_to_output_below => {
            const target_output_idx = getOutputInDirection(
                wm.output_list,
                output.rect,
                .below,
            ) orelse return;

            const target_output = wm.output_list.items[target_output_idx];
            const target_workspace_idx = target_output.focused_workspace_idx;

            try sendFocusedWindowToWorkspace(
                allocator,
                workspace,
                &target_output.workspace_list.items[target_workspace_idx],
            );
        },
    }

    layout.update(wm.allocator, wm.output_list, wm.config);
    wm.task = .layout;
}

fn sendFocusedWindowToWorkspace(
    allocator: std.mem.Allocator,
    current: *types.Workspace,
    target: *types.Workspace,
) !void {
    const window_idx = current.focused_window_idx orelse return error.NoFocusedWindow;
    const window = current.window_list.orderedRemove(window_idx);

    if (current.window_list.items.len == 0) {
        current.focused_window_idx = null;
    } else if (window_idx != 0) {
        current.focused_window_idx = window_idx - 1;
    }

    var target_window_idx: usize = 0;
    if (target.focused_window_idx) |idx| {
        target_window_idx = idx + 1;
    }

    try target.window_list.insert(allocator, target_window_idx, window);
    target.focused_window_idx = target_window_idx;
}

const Direction = enum { left, right, above, below };

fn getOutputInDirection(
    output_list: std.ArrayList(types.Output),
    current_rect: types.Rectangle,
    direction: Direction,
) ?usize {
    for (output_list.items, 0..) |output, output_idx| {
        const target_rect = output.rect;

        const is_adjacent = switch (direction) {
            .left => target_rect.x + target_rect.width == current_rect.x,
            .right => current_rect.x + current_rect.width == target_rect.x,
            .above => target_rect.y + target_rect.height == current_rect.y,
            .below => current_rect.y + current_rect.height == target_rect.y,
        };

        if (is_adjacent) return output_idx;
    }

    return null;
}

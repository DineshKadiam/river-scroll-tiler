const std = @import("std");

const wayland = @import("wayland");
const river = wayland.client.river;

const types = @import("types.zig");

pub const edges = river.WindowV1.Edges{
    .top = true,
    .bottom = true,
    .left = true,
    .right = true,
};

pub fn apply(
    allocator: std.mem.Allocator,
    output_list: std.ArrayList(types.Output),
    focused_output_idx: usize,
    config: types.Config,
    river_seat: *river.SeatV1,
) !void {
    river_seat.clearFocus();

    for (output_list.items, 0..) |*output, output_idx| {
        if (output.river_output == null) continue;

        if (config.dynamic_workspaces) {
            try handleDynamicWorkspaces(allocator, output);
        }

        const non_exclusive = output.non_exclusive orelse output.rect;

        for (output.workspace_list.items, 0..) |workspace, workspace_idx| {
            const workspace_offset =
                @as(i32, @intCast(workspace_idx)) -
                @as(i32, @intCast(output.focused_workspace_idx));

            const y_offset = workspace_offset * output.rect.height;

            if (workspace.is_floating) {
                floatingLayout(
                    workspace.window_list,
                    non_exclusive,
                    output.rect,
                    config,
                    y_offset,
                );
            } else {
                scrollingLayout(
                    workspace,
                    non_exclusive,
                    output.rect,
                    config,
                    y_offset,
                );
            }

            for (workspace.window_list.items, 0..) |window, window_idx| {
                window.river_window.exitFullscreen();

                const unfocused_color = config.border.unfocused_color.toRiverColor();
                window.river_window.setBorders(
                    edges,
                    config.border.width,
                    unfocused_color.r,
                    unfocused_color.g,
                    unfocused_color.b,
                    unfocused_color.a,
                );

                if (window.should_close) window.river_window.close();

                if (output_idx != focused_output_idx) continue;
                if (workspace_idx != output.focused_workspace_idx) continue;
                if (window_idx != workspace.focused_window_idx) continue;

                const focused_color = config.border.focused_color.toRiverColor();
                window.river_window.setBorders(
                    edges,
                    config.border.width,
                    focused_color.r,
                    focused_color.g,
                    focused_color.b,
                    focused_color.a,
                );

                window.river_node.placeTop();
                river_seat.focusWindow(window.river_window);
            }
        }

        if (output_idx != focused_output_idx) continue;
        if (output.river_layer_shell_output) |layer_shell_output| {
            layer_shell_output.setDefault();
        }
    }
}

fn handleDynamicWorkspaces(
    allocator: std.mem.Allocator,
    output: *types.Output,
) !void {
    const focused_idx = output.focused_workspace_idx;

    var workspace_idx = output.workspace_list.items.len;
    while (workspace_idx > 0) {
        workspace_idx -= 1;
        const workspace = output.workspace_list.items[workspace_idx];

        if (workspace.window_list.items.len > 0) continue;
        if (workspace_idx == focused_idx) continue;

        _ = output.workspace_list.orderedRemove(workspace_idx);

        if (workspace_idx < focused_idx and focused_idx != 0) {
            output.focused_workspace_idx -= 1;
        }
    }

    try output.workspace_list.append(allocator, .{});
}

fn floatingLayout(
    window_list: std.ArrayList(types.Window),
    non_exclusive: types.Rectangle,
    output_rect: types.Rectangle,
    config: types.Config,
    y_offset: i32,
) void {
    for (window_list.items) |*window| {
        window.start_rect = window.current_rect;

        if (window.is_maximized) {
            const h_gap = config.horizontal_gap;
            const v_gap = config.vertical_gap;

            window.finish_rect = .{
                .width = non_exclusive.width - 2 * h_gap,
                .height = non_exclusive.height - 2 * v_gap,
                .x = non_exclusive.x + h_gap,
                .y = non_exclusive.y + v_gap,
            };
        } else if (window.is_fullscreen) {
            window.finish_rect = output_rect;
        } else {
            window.finish_rect = window.floating_rect;
        }

        window.finish_rect.?.y += y_offset;
    }
}

fn scrollingLayout(
    workspace: types.Workspace,
    non_exclusive: types.Rectangle,
    output_rect: types.Rectangle,
    config: types.Config,
    y_offset: i32,
) void {
    const focused_window_idx = workspace.focused_window_idx orelse return;
    const focused_window = &workspace.window_list.items[focused_window_idx];

    var placement_rect: types.Rectangle = undefined;
    const should_center = switch (config.center_focused_window) {
        .never => false,
        .always => true,
        .single => workspace.window_list.items.len == 1,
    };

    focusedWindowLayout(
        focused_window,
        &placement_rect,
        non_exclusive,
        output_rect,
        config,
        y_offset,
        should_center,
    );

    focused_window.finish_rect = placement_rect;
    placement_rect.x += placement_rect.width + config.horizontal_gap;

    for (workspace.window_list.items[focused_window_idx + 1 ..]) |*window| {
        unfocusedWindowLayout(
            window,
            &placement_rect,
            non_exclusive,
            output_rect,
            config,
            y_offset,
        );

        window.finish_rect = placement_rect;
        placement_rect.x += placement_rect.width + config.horizontal_gap;
    }

    const focused_window_rect = focused_window.finish_rect orelse return;
    placement_rect.x = focused_window_rect.x;

    var window_idx = focused_window_idx;
    while (window_idx > 0) {
        window_idx -= 1;
        const window = &workspace.window_list.items[window_idx];

        unfocusedWindowLayout(
            window,
            &placement_rect,
            non_exclusive,
            output_rect,
            config,
            y_offset,
        );

        placement_rect.x -= config.horizontal_gap + placement_rect.width;
        window.finish_rect = placement_rect;
    }

    if (!should_center) snapToEdge(
        workspace.window_list,
        non_exclusive,
        config.horizontal_gap,
    );
}

fn focusedWindowLayout(
    window: *types.Window,
    placement_rect: *types.Rectangle,
    non_exclusive: types.Rectangle,
    output_rect: types.Rectangle,
    config: types.Config,
    y_offset: i32,
    should_center: bool,
) void {
    const h_gap = config.horizontal_gap;
    const v_gap = config.vertical_gap;

    var proportion = window.proportion;
    if (window.is_maximized) proportion = 1.0;

    const base_width: f32 = @floatFromInt(non_exclusive.width - h_gap);
    const width_with_gap: i32 = @trunc(base_width * proportion);

    placement_rect.* = .{
        .width = width_with_gap - h_gap,
        .height = non_exclusive.height - 2 * v_gap,
        .x = window.current_rect.x,
        .y = non_exclusive.y + v_gap + y_offset,
    };

    const left_bound = non_exclusive.x + h_gap;
    const right_bound = non_exclusive.x + non_exclusive.width;

    if (should_center) {
        const center = non_exclusive.x + @divTrunc(non_exclusive.width, 2);
        placement_rect.x = center - @divTrunc(placement_rect.width, 2);
    } else if (placement_rect.x < left_bound) {
        placement_rect.x = left_bound;
    } else if (placement_rect.x + width_with_gap > right_bound) {
        placement_rect.x = @max(
            right_bound - width_with_gap,
            left_bound,
        );
    }

    if (window.is_fullscreen) {
        placement_rect.* = output_rect;
        placement_rect.y += y_offset;
    }

    window.start_rect = window.current_rect;
}

fn unfocusedWindowLayout(
    window: *types.Window,
    placement_rect: *types.Rectangle,
    non_exclusive: types.Rectangle,
    output_rect: types.Rectangle,
    config: types.Config,
    y_offset: i32,
) void {
    if (window.is_fullscreen) {
        placement_rect.width = output_rect.width;
        placement_rect.height = output_rect.height;
        placement_rect.y = output_rect.y + y_offset;
    } else {
        const h_gap = config.horizontal_gap;
        const v_gap = config.vertical_gap;

        var proportion = window.proportion;
        if (window.is_maximized) proportion = 1.0;

        const base_width: f32 = @floatFromInt(non_exclusive.width - h_gap);
        const width_with_gap: i32 = @trunc(base_width * proportion);

        placement_rect.width = width_with_gap - h_gap;
        placement_rect.height = non_exclusive.height - 2 * v_gap;
        placement_rect.y = non_exclusive.y + v_gap + y_offset;
    }

    window.start_rect = window.current_rect;
}

fn snapToEdge(
    window_list: std.ArrayList(types.Window),
    non_exclusive: types.Rectangle,
    h_gap: i32,
) void {
    const head_rect = window_list.items[0].finish_rect orelse return;
    const head_x = head_rect.x;
    const left_bound = non_exclusive.x + h_gap;

    var head_distance: ?i32 = null;
    if (head_x > left_bound) {
        head_distance = head_x - left_bound;
    }

    const tail_window = window_list.items[window_list.items.len - 1];
    const tail_rect = tail_window.finish_rect orelse return;
    const tail_x = tail_rect.x + tail_rect.width;
    const right_bound = non_exclusive.x + non_exclusive.width - h_gap;

    var tail_distance: ?i32 = null;
    if (tail_x < right_bound) {
        tail_distance = @min(right_bound - tail_x, left_bound - head_x);
    }

    for (window_list.items) |*window| {
        const x = &window.finish_rect.?.x;
        if (head_distance) |distance| {
            x.* -= distance;
        } else if (tail_distance) |distance| {
            x.* += distance;
        }
    }
}

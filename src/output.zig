const std = @import("std");

const wayland = @import("wayland");
const river = wayland.client.river;

const layout = @import("layout.zig");
const types = @import("types.zig");

pub fn add(
    allocator: std.mem.Allocator,
    river_output: *river.OutputV1,
    wm: *types.WindowManager,
) !void {
    river_output.setListener(*types.WindowManager, outputListener, wm);

    for (wm.output_list.items, 0..) |*output, idx| {
        if (output.river_output != null) continue;

        output.river_output = river_output;
        output.river_layer_shell_output = try getLayerShellOutput(river_output, wm);

        wm.focused_output_idx = idx;
        return;
    }

    var workspace_count = wm.config.workspace_count;
    if (wm.config.dynamic_workspaces) workspace_count = 1;

    var workspace_list = std.ArrayList(types.Workspace).empty;
    while (workspace_count > 0) : (workspace_count -= 1) {
        try workspace_list.append(allocator, .{});
    }

    const output = types.Output{
        .river_output = river_output,
        .river_layer_shell_output = try getLayerShellOutput(river_output, wm),
        .workspace_list = workspace_list,
        .focused_workspace_idx = 0,
        .rect = undefined,
        .non_exclusive = null,
    };

    try wm.output_list.append(allocator, output);
    wm.focused_output_idx = wm.output_list.items.len - 1;
}

fn getLayerShellOutput(
    river_output: *river.OutputV1,
    wm: *types.WindowManager,
) !?*river.LayerShellOutputV1 {
    const layer_shell = wm.river_layer_shell orelse return null;
    const layer_shell_output = try layer_shell.getOutput(river_output);

    layer_shell_output.setListener(*types.WindowManager, layerShellOutputListener, wm);
    return layer_shell_output;
}

fn outputListener(
    river_output: *river.OutputV1,
    event: river.OutputV1.Event,
    wm: *types.WindowManager,
) void {
    for (wm.output_list.items, 0..) |*output, idx| {
        if (output.river_output != river_output) continue;

        switch (event) {
            .dimensions => |dimensions| {
                output.rect.width = dimensions.width;
                output.rect.height = dimensions.height;
            },
            .position => |position| {
                output.rect.x = position.x;
                output.rect.y = position.y;
            },
            .removed => {
                river_output.destroy();
                output.river_output = null;

                if (output.river_layer_shell_output) |river_layer_shell_output| {
                    river_layer_shell_output.destroy();
                }

                const focused_idx = wm.focused_output_idx orelse return;
                if (wm.output_list.items.len == 1) {
                    wm.focused_output_idx = null;
                } else if (idx <= focused_idx and focused_idx != 0) {
                    wm.focused_output_idx = focused_idx - 1;
                }

                const previous_workspace = wm.previous_workspace orelse return;
                const previous_idx = previous_workspace.output_idx;

                if (idx == previous_idx) {
                    wm.previous_workspace = null;
                } else if (idx < previous_idx and previous_idx != 0) {
                    wm.previous_workspace.?.output_idx -= 1;
                }

                wm.task = .layout;
            },
            else => {},
        }
        return;
    }
}

fn layerShellOutputListener(
    river_layer_shell_output: *river.LayerShellOutputV1,
    event: river.LayerShellOutputV1.Event,
    wm: *types.WindowManager,
) void {
    for (wm.output_list.items) |*output| {
        if (output.river_layer_shell_output != river_layer_shell_output) continue;

        switch (event) {
            .non_exclusive_area => |area| {
                output.non_exclusive = .{
                    .width = area.width,
                    .height = area.height,
                    .x = area.x,
                    .y = area.y,
                };

                wm.task = .layout;
            },
        }
        return;
    }
}

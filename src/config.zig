const std = @import("std");

const types = @import("types.zig");

const Location = enum { XDG_CONFIG_HOME, HOME };

pub fn load(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
) types.Config {
    if (loadConfigFrom(allocator, io, environ_map, .XDG_CONFIG_HOME)) |config| {
        return config;
    } else |err| {
        std.debug.print("Failed to load config from $XDG_CONFIG_HOME: {}\n", .{err});
    }

    if (loadConfigFrom(allocator, io, environ_map, .HOME)) |config| {
        return config;
    } else |err| {
        std.debug.print("Failed to load config from $HOME: {}\n", .{err});
    }

    return .{};
}

fn loadConfigFrom(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    location: Location,
) !types.Config {
    const env = environ_map.get(@tagName(location)) orelse
        return error.EnvironmentVariableNotFound;

    const path = switch (location) {
        .XDG_CONFIG_HOME => try std.Io.Dir.path.join(allocator, &.{
            env,
            "rill",
            "config.zon",
        }),
        .HOME => try std.Io.Dir.path.join(allocator, &.{
            env,
            ".config",
            "rill",
            "config.zon",
        }),
    };
    defer allocator.free(path);

    const content = try std.Io.Dir.cwd().readFileAllocOptions(
        io,
        path,
        allocator,
        .unlimited,
        .@"16",
        0,
    );
    defer allocator.free(content);

    const config = try std.zon.parse.fromSliceAlloc(
        types.Config,
        allocator,
        content,
        null,
        .{},
    );

    return config;
}

pub const default_keybindings = [_]types.Keybinding{
    .{ .key = "q", .modifiers = .{ .mod4 = true }, .action = .close_window },
    .{ .key = "f", .modifiers = .{ .mod4 = true }, .action = .toggle_maximize },
    .{ .key = "f", .modifiers = .{ .mod4 = true, .shift = true }, .action = .toggle_fullscreen },

    .{ .key = "minus", .modifiers = .{ .mod4 = true }, .action = .{ .adjust_window_width = -0.1 } },
    .{ .key = "equal", .modifiers = .{ .mod4 = true }, .action = .{ .adjust_window_width = 0.1 } },

    .{ .key = "Escape", .modifiers = .{ .mod4 = true }, .action = .exit },
    .{ .key = "r", .modifiers = .{ .mod4 = true }, .action = .reload_config },
    .{ .key = "t", .modifiers = .{ .mod4 = true }, .action = .{ .spawn = &[_][]const u8{"alacritty"} } },

    .{ .key = "Left", .modifiers = .{ .mod4 = true }, .action = .focus_window_left },
    .{ .key = "Right", .modifiers = .{ .mod4 = true }, .action = .focus_window_right },

    .{ .key = "Left", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_left },
    .{ .key = "Right", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_right },

    .{ .key = "Up", .modifiers = .{ .mod4 = true }, .action = .focus_workspace_above },
    .{ .key = "Down", .modifiers = .{ .mod4 = true }, .action = .focus_workspace_below },

    .{ .key = "1", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 1 } },
    .{ .key = "2", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 2 } },
    .{ .key = "3", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 3 } },
    .{ .key = "4", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 4 } },
    .{ .key = "5", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 5 } },
    .{ .key = "6", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 6 } },
    .{ .key = "7", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 7 } },
    .{ .key = "8", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 8 } },
    .{ .key = "9", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 9 } },
    .{ .key = "0", .modifiers = .{ .mod4 = true }, .action = .{ .focus_workspace_number = 10 } },

    .{ .key = "Up", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_workspace_above },
    .{ .key = "Down", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_workspace_below },

    .{ .key = "1", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 1 } },
    .{ .key = "2", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 2 } },
    .{ .key = "3", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 3 } },
    .{ .key = "4", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 4 } },
    .{ .key = "5", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 5 } },
    .{ .key = "6", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 6 } },
    .{ .key = "7", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 7 } },
    .{ .key = "8", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 8 } },
    .{ .key = "9", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 9 } },
    .{ .key = "0", .modifiers = .{ .mod4 = true, .shift = true }, .action = .{ .move_window_to_workspace_number = 10 } },

    .{ .key = "Up", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_workspace_above },
    .{ .key = "Down", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_workspace_below },

    .{ .key = "1", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 1 } },
    .{ .key = "2", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 2 } },
    .{ .key = "3", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 3 } },
    .{ .key = "4", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 4 } },
    .{ .key = "5", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 5 } },
    .{ .key = "6", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 6 } },
    .{ .key = "7", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 7 } },
    .{ .key = "8", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 8 } },
    .{ .key = "9", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 9 } },
    .{ .key = "0", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .{ .send_window_to_workspace_number = 10 } },

    .{ .key = "h", .modifiers = .{ .mod4 = true }, .action = .focus_output_left },
    .{ .key = "l", .modifiers = .{ .mod4 = true }, .action = .focus_output_right },
    .{ .key = "k", .modifiers = .{ .mod4 = true }, .action = .focus_output_above },
    .{ .key = "j", .modifiers = .{ .mod4 = true }, .action = .focus_output_below },

    .{ .key = "h", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_left },
    .{ .key = "l", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_right },
    .{ .key = "k", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_above },
    .{ .key = "j", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_below },

    .{ .key = "h", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_output_left },
    .{ .key = "l", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_output_right },
    .{ .key = "k", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_output_above },
    .{ .key = "j", .modifiers = .{ .mod4 = true, .ctrl = true }, .action = .send_window_to_output_below },
};

pub const default_pointer_bindings = [_]types.PointerBinding{
    .{ .button = .left, .modifiers = .{ .mod4 = true }, .action = .move_window },
    .{ .button = .right, .modifiers = .{ .mod4 = true }, .action = .resize_window },
};

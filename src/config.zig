const std = @import("std");

const types = @import("types.zig");

const Location = enum { XDG_CONFIG_HOME, HOME };

pub fn load(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: std.process.Environ.Map,
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
    environ_map: std.process.Environ.Map,
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
    .{ .key = "BackSpace", .modifiers = .{ .mod4 = true }, .action = .{ .set_window_width = 0.5 } },

    .{ .key = "Left", .modifiers = .{ .mod4 = true }, .action = .focus_window_left },
    .{ .key = "Right", .modifiers = .{ .mod4 = true }, .action = .focus_window_right },
    .{ .key = "Left", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_left },
    .{ .key = "Right", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_right },

    .{ .key = "v", .modifiers = .{ .mod4 = true }, .action = .toggle_workspace_floating },

    .{ .key = "Up", .modifiers = .{ .mod4 = true }, .action = .focus_workspace_above },
    .{ .key = "Down", .modifiers = .{ .mod4 = true }, .action = .focus_workspace_below },
    .{ .key = "grave", .modifiers = .{ .mod4 = true }, .action = .focus_workspace_previous },

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

    .{ .key = "h", .modifiers = .{ .mod4 = true }, .action = .focus_output_left },
    .{ .key = "l", .modifiers = .{ .mod4 = true }, .action = .focus_output_right },
    .{ .key = "k", .modifiers = .{ .mod4 = true }, .action = .focus_output_above },
    .{ .key = "j", .modifiers = .{ .mod4 = true }, .action = .focus_output_below },

    .{ .key = "h", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_left },
    .{ .key = "l", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_right },
    .{ .key = "k", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_above },
    .{ .key = "j", .modifiers = .{ .mod4 = true, .shift = true }, .action = .move_window_to_output_below },

    .{ .key = "Escape", .modifiers = .{ .mod4 = true }, .action = .exit },
    .{ .key = "r", .modifiers = .{ .mod4 = true }, .action = .reload_config },

    .{ .key = "t", .modifiers = .{ .mod4 = true }, .action = .{ .spawn = &[_][]const u8{"alacritty"} } },

    .{
        .key = "XF86AudioRaiseVolume",
        .modifiers = .{},
        .action = .{ .spawn = &[_][]const u8{ "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.05+", "--limit", "1.0" } },
    },
    .{
        .key = "XF86AudioLowerVolume",
        .modifiers = .{},
        .action = .{ .spawn = &[_][]const u8{ "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.05-" } },
    },
    .{
        .key = "XF86AudioMute",
        .modifiers = .{},
        .action = .{ .spawn = &[_][]const u8{ "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" } },
    },
    .{
        .key = "XF86AudioMicMute",
        .modifiers = .{},
        .action = .{ .spawn = &[_][]const u8{ "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle" } },
    },
};

pub const default_pointer_bindings = [_]types.PointerBinding{
    .{ .button = .left, .modifiers = .{ .mod4 = true }, .action = .move_window },
    .{ .button = .right, .modifiers = .{ .mod4 = true }, .action = .resize_window },
};

test "validate default config file" {
    const fields = std.meta.fields(types.Config);

    const config_struct = types.Config{};
    const config_file: types.Config = @import("default_config");

    inline for (fields) |field| {
        const has_field = @hasField(@TypeOf(@import("default_config")), field.name);
        if (!has_field) {
            std.debug.print("Default config file is missing field '{s}'\n", .{field.name});
            try std.testing.expect(has_field);
        }

        const struct_value = @field(config_struct, field.name);
        const file_value = @field(config_file, field.name);

        std.testing.expectEqualDeep(struct_value, file_value) catch |err| {
            std.debug.print("Value of '{s}' doesn't match\n", .{field.name});
            return err;
        };
    }
}

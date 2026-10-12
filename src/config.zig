const std = @import("std");

const types = @import("types.zig");

const Location = enum { XDG_CONFIG_HOME, HOME };

pub fn load(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: *std.heap.ArenaAllocator,
    environ_map: *std.process.Environ.Map,
) types.Config {
    if (loadConfigFrom(gpa, io, arena, environ_map, .XDG_CONFIG_HOME)) |config| {
        return config;
    } else |err| {
        std.debug.print("Failed to load config from $XDG_CONFIG_HOME: {}\n", .{err});
    }

    if (loadConfigFrom(gpa, io, arena, environ_map, .HOME)) |config| {
        return config;
    } else |err| {
        std.debug.print("Failed to load config from $HOME: {}\n", .{err});
    }

    return .{};
}

fn loadConfigFrom(
    gpa: std.mem.Allocator,
    io: std.Io,
    arena: *std.heap.ArenaAllocator,
    environ_map: *std.process.Environ.Map,
    location: Location,
) !types.Config {
    const env = environ_map.get(@tagName(location)) orelse
        return error.EnvironmentVariableNotFound;

    const path = switch (location) {
        .XDG_CONFIG_HOME => try std.Io.Dir.path.join(gpa, &.{
            env,
            "rill",
            "config.zon",
        }),
        .HOME => try std.Io.Dir.path.join(gpa, &.{
            env,
            ".config",
            "rill",
            "config.zon",
        }),
    };
    defer gpa.free(path);

    const content = try std.Io.Dir.cwd().readFileAllocOptions(
        io,
        path,
        gpa,
        .unlimited,
        .@"16",
        0,
    );
    defer gpa.free(content);

    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const config = try std.zon.parse.fromSlice(
        types.Config,
        .{
            .gpa = gpa,
            .arena = arena.allocator(),
            .source = content,
            .diagnostics = &diagnostics,
        },
    );

    return config;
}

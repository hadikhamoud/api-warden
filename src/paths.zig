const std = @import("std");

fn getHome() ![]const u8 {
    if (std.posix.getenv("HOME")) |value| {
        return value;
    } else {
        std.log.err("HOME environment variable not set.", .{});
        std.process.exit(1);
    }
}

pub fn getDataPath(alloc: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_DATA_HOME")) |data_home| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{data_home});
    }

    const home_path = try getHome();
    return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
}

pub fn getConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |config_home| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{config_home});
    }

    const home_path = try getHome();
    return try std.fmt.allocPrint(alloc, "{s}/.config/api-warden", .{home_path});
}

pub fn initializeWardenFiles(alloc: std.mem.Allocator) !void {
    const data_path = try getDataPath(alloc);
    defer alloc.free(data_path);
    std.fs.cwd().makePath(data_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const config_path = try getConfigPath(alloc);
    defer alloc.free(config_path);
    std.fs.cwd().makePath(config_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

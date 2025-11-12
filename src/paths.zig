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
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_DATA_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
    }
}

pub fn getConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_CONFIG_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.config/api-warden", .{home_path});
    }
}

pub fn initializeWardenFiles(alloc: std.mem.Allocator) !void {
    const data_path = try getDataPath(alloc);
    defer alloc.free(data_path);
    const mode: u32 = 0o755;
    if (std.posix.mkdir(data_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }

    const config_path = try getConfigPath(alloc);
    defer alloc.free(config_path);
    if (std.posix.mkdir(config_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }
}

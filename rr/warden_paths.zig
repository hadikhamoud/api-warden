const std = @import("std");

fn getHome() ![]const u8 {
    if (std.posix.getenv("HOME")) |value| {
        return value;
    } else {
        std.log.err("HOME environment variable not set.", .{});
        std.process.exit(1);
    }
}

pub fn setDataPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_DATA_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
    }
}

pub fn setConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_CONFIG_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.config/api-warden", .{home_path});
    }
}

const std = @import("std");
const builtin = @import("builtin");

fn getHome(alloc: std.mem.Allocator) ![]const u8 {
    const env_var = if (builtin.os.tag == .windows) "USERPROFILE" else "HOME";

    if (builtin.os.tag == .windows) {
        return std.process.getEnvVarOwned(alloc, env_var) catch |err| {
            std.log.err("{s} environment variable not set: {any}", .{ env_var, err });
            std.process.exit(1);
        };
    } else {
        if (std.posix.getenv(env_var)) |value| {
            return value;
        } else {
            std.log.err("{s} environment variable not set.", .{env_var});
            std.process.exit(1);
        }
    }
}

pub fn getDataPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();

    if (builtin.os.tag == .windows) {
        const home_path = try getHome(alloc);
        defer alloc.free(home_path);
        return try std.fmt.allocPrint(alloc, "{s}\\AppData\\Local\\api-warden", .{home_path});
    }

    if (current_env.get("XDG_DATA_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome(alloc);
        return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
    }
}

pub fn getConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();

    if (builtin.os.tag == .windows) {
        const home_path = try getHome(alloc);
        defer alloc.free(home_path);
        return try std.fmt.allocPrint(alloc, "{s}\\AppData\\Roaming\\api-warden", .{home_path});
    }

    if (current_env.get("XDG_CONFIG_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome(alloc);
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

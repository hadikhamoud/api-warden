const std = @import("std");

fn getHome() ![]const u8 {
    if (std.posix.getenv("HOME")) |value| {
        return value;
    } else {
        std.log.err("HOME environment variable not set.", .{});
        std.process.exit(1);
    }
}

fn getXdgConfig(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_CONFIG_HOME")) |value| {
        return value;
    } else {
        const home_path = try getHome();
        const config_path = try std.fmt.allocPrint(alloc, "{s}/.config", .{home_path});
        std.fs.cwd().makePath(config_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        return config_path;
    }
}

fn getXdgData(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_DATA_HOME")) |value| {
        return value;
    } else {
        const home_path = try getHome();
        const data_path = try std.fmt.allocPrint(alloc, "{s}/.local/share", .{home_path});
        std.fs.cwd().makePath(data_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        return data_path;
    }
}

pub fn getDataPath(alloc: std.mem.Allocator) ![]const u8 {
    const data_path = try getXdgData(alloc);
    return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{data_path});
}

pub fn getConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    const config_path = try getXdgConfig(alloc);
    return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{config_path});
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

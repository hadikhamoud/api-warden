const std = @import("std");
const rest_methods = @import("rest.zig");

fn getHome() ![]const u8 {
    if (std.posix.getenv("HOME")) |value| {
        return value;
    } else {
        std.log.err("HOME environment variable not set.", .{});
        std.process.exit(1);
    }
}

fn setDataPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_DATA_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
    }
}

fn setConfigPath(alloc: std.mem.Allocator) ![]const u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_CONFIG_HOME")) |value| {
        return try std.fmt.allocPrint(alloc, "{s}/api-warden", .{value});
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.config/api-warden", .{home_path});
    }
}

fn startProcess(arguments: [][:0]u8, alloc: std.mem.Allocator) !i32 {
    var child = std.process.Child.init(arguments, alloc);
    _ = try child.spawnAndWait();
    return child.id;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Error", .{});
        return;
    }

    const data_path = try setDataPath(allocator);
    const mode: u32 = 0o755;
    if (std.posix.mkdir(data_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }
    defer allocator.free(data_path);

    const config_path = try setConfigPath(allocator);
    if (std.posix.mkdir(data_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }
    defer allocator.free(config_path);

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "get")) {
        const url = args[2];
        const response = try rest_methods.get(url, allocator);
        defer allocator.free(response);
        std.debug.print("{s}", .{response});
    } else if (std.mem.eql(u8, cmd, "run")) {
        const arguments = args[2..args.len];
        const pid = try startProcess(arguments, allocator);
        std.debug.print("\nprocess ID: {d}\n", .{pid});
    } else if (std.mem.eql(u8, cmd, "post")) {
        const headers = &[_]std.http.Header{
            .{ .name = "X-API-Key", .value = "" },
            .{ .name = "Content-Type", .value = "application/json" },
        };
        const url = args[2];
        const body = if (args.len > 3) args[3] else "";
        const response = try rest_methods.post(url, headers, body, allocator);
        defer allocator.free(response);
        std.debug.print("{s}", .{response});
    } else {
        std.debug.print("\nWrite a command", .{});
    }
    return;
}

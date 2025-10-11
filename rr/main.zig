const std = @import("std");
const HealthzResponse = struct { status: []const u8 };

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

fn get(uri: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var buffer = try std.Io.Writer.Allocating.initCapacity(alloc, 1024);
    defer buffer.deinit();
    const headers = &[_]std.http.Header{};
    const response = try client.fetch(.{ .method = .GET, .location = .{ .url = uri }, .extra_headers = headers, .response_writer = &buffer.writer });
    if (response.status != .ok) {
        std.log.debug("Error {d} {s}", .{ response.status, response.status.phrase() orelse "???" });
    }

    const items = try buffer.toOwnedSlice();
    return items;
}

fn post(uri: []const u8, headers: []const std.http.Header, payload: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();
    var buffer = try std.Io.Writer.Allocating.initCapacity(alloc, 1024);
    defer buffer.deinit();

    const response = try client.fetch(.{
        .method = .POST,
        .location = .{ .url = uri },
        .extra_headers = headers,
        .response_writer = &buffer.writer,
        .payload = payload,
    });

    if (response.status != .ok) {
        std.log.debug("Error {d} {s}", .{ response.status, response.status.phrase() orelse "???" });
    }

    const items = buffer.toOwnedSlice();
    return items;
}

fn startProcess(arguments: [][:0]u8, alloc: std.mem.Allocator) !i32 {
    var child = std.process.Child.init(arguments, alloc);
    try child.spawn();
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

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "get")) {
        const url = args[2];
        const response = try get(url, allocator);
        defer allocator.free(response);
        std.debug.print("{s}", .{response});
    } else if (std.mem.eql(u8, cmd, "run")) {
        const arguments = args[2..args.len];
        const pid = try startProcess(arguments, allocator);
        std.debug.print("\nprocess ID: {d}", .{pid});
    } else if (std.mem.eql(u8, cmd, "post")) {
        const headers = &[_]std.http.Header{
            .{ .name = "X-API-Key", .value = "" },
            .{ .name = "Content-Type", .value = "application/json" },
        };
        const url = args[2];
        const body = if (args.len > 3) args[3] else "";
        const response = try post(url, headers, body, allocator);
        defer allocator.free(response);
        std.debug.print("{s}", .{response});
    } else {
        std.debug.print("\nWrite a command", .{});
    }
    return;
}

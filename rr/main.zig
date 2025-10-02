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

fn setDataPath(alloc: std.mem.Allocator) ![]u8 {
    var current_env = try std.process.getEnvMap(alloc);
    defer current_env.deinit();
    if (current_env.get("XDG_DATA_HOME")) |value| {
        std.debug.print("{s}", .{value});
        return try alloc.dupe(u8, value);
    } else {
        const home_path = try getHome();
        return try std.fmt.allocPrint(alloc, "{s}/.local/share/api-warden", .{home_path});
    }
}

fn get(uri: []const u8, alloc: std.mem.Allocator) !HealthzResponse {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var buffer = try std.Io.Writer.Allocating.initCapacity(alloc, 1024);
    defer buffer.deinit();
    const headers = &[_]std.http.Header{};
    const response = try client.fetch(.{ .method = .GET, .location = .{ .url = uri }, .extra_headers = headers, .response_writer = &buffer.writer });
    if (response.status != .ok) {
        std.log.debug("Error {d} {s}", .{ response.status, response.status.phrase() orelse "???" });
    }

    var list = buffer.toArrayList();
    defer list.deinit(alloc);
    const items: []u8 = list.items;

    const parsed = try std.json.parseFromSlice(*HealthzResponse, alloc, items, .{});
    defer parsed.deinit();
    const status_copy = try alloc.dupe(u8, parsed.value.status);
    return HealthzResponse{ .status = status_copy };
}

fn post(uri: []const u8, headers: std.StringHashMap, alloc: std.mem.Allocator) !void {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();
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
    defer allocator.free(data_path);
    std.debug.print("{s}", .{data_path});
    const arguments = args[1..args.len];
    const pid = try startProcess(arguments, allocator);
    std.debug.print("process ID: {d}", .{pid});
}

const std = @import("std");

pub fn get(uri: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var buffer = try std.Io.Writer.Allocating.initCapacity(alloc, 1024);
    defer buffer.deinit();
    const headers = &[_]std.http.Header{};
    const response = try client.fetch(.{ .method = .GET, .location = .{ .url = uri }, .extra_headers = headers, .response_writer = &buffer.writer });
    if (response.status != .ok) {
        std.log.err("Error {d} {s}", .{ response.status, response.status.phrase() orelse "???" });
    }

    const items = try buffer.toOwnedSlice();
    return items;
}

pub fn post(uri: []const u8, headers: []const std.http.Header, payload: []const u8, alloc: std.mem.Allocator) !?[]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var request_headers = try std.ArrayList(std.http.Header).initCapacity(alloc, headers.len + 1);
    defer request_headers.deinit(alloc);
    try request_headers.appendSlice(alloc, headers);

    var has_content_type = false;
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "Content-Type")) {
            has_content_type = true;
            break;
        }
    }
    if (!has_content_type) {
        try request_headers.append(alloc, .{ .name = "Content-Type", .value = "application/json" });
    }

    var buffer = try std.Io.Writer.Allocating.initCapacity(alloc, 1024);
    errdefer buffer.deinit();

    const response = try client.fetch(.{
        .method = .POST,
        .location = .{ .url = uri },
        .extra_headers = request_headers.items,
        .payload = payload,
        .response_writer = &buffer.writer,
        .keep_alive = false,
    });

    if (response.status != .ok and response.status != .no_content) {
        std.log.err("Error {d} {s}", .{ response.status, response.status.phrase() orelse "???" });
    }

    const items = try buffer.toOwnedSlice();
    if (items.len == 0) {
        alloc.free(items);
        return null;
    }
    return items;
}

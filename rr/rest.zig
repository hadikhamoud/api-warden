const std = @import("std");

pub fn get(uri: []const u8, alloc: std.mem.Allocator) ![]const u8 {
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

pub fn post(uri: []const u8, headers: []const std.http.Header, payload: []const u8, alloc: std.mem.Allocator) ![]const u8 {
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

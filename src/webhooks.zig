const std = @import("std");
const xdg = @import("paths.zig");
const utils = @import("utils.zig");

pub const WebhookDetails = struct {
    url: []const u8,
    headers: []std.http.Header,
};

pub const WebhookList = struct {
    items: []WebhookDetails,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *WebhookList) void {
        self.arena.deinit();
    }

    pub fn sortByUrl(self: *WebhookList) void {
        std.mem.sort(WebhookDetails, self.items, {}, struct {
            fn lessThan(_: void, a: WebhookDetails, b: WebhookDetails) bool {
                return std.mem.lessThan(u8, a.url, b.url);
            }
        }.lessThan);
    }

    pub fn load(allocator: std.mem.Allocator) !WebhookList {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_alloc = arena.allocator();

        var webhooks = try std.ArrayList(WebhookDetails).initCapacity(arena_alloc, 32);

        const data_path = try xdg.getDataPath(arena_alloc);
        const webhook_dir_path = try std.fmt.allocPrint(arena_alloc, "{s}/webhooks", .{data_path});

        var webhook_dir = try std.fs.openDirAbsolute(webhook_dir_path, .{ .iterate = true });
        defer webhook_dir.close();

        var webhook_dir_iterator = webhook_dir.iterate();
        while (try webhook_dir_iterator.next()) |dirContent| {
            if (dirContent.kind == .file) {
                const webhook_file = try std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ webhook_dir_path, dirContent.name });
                const file = try std.fs.openFileAbsolute(webhook_file, .{});
                defer file.close();
                const stat = try file.stat();
                const buffer = try file.readToEndAlloc(arena_alloc, stat.size);

                const parsed = try std.json.parseFromSlice(WebhookDetails, arena_alloc, buffer, .{ .allocate = .alloc_always });
                try webhooks.append(arena_alloc, parsed.value);
            }
        }

        return WebhookList{
            .items = try webhooks.toOwnedSlice(arena_alloc),
            .arena = arena,
        };
    }
};

pub fn writeWebhookDetails(webhook_details: WebhookDetails, allocator: std.mem.Allocator) !void {
    const data_path = try xdg.getDataPath(allocator);
    const webhook_dir_path = try std.fmt.allocPrint(allocator, "{s}/webhooks", .{data_path});
    defer allocator.free(data_path);
    defer allocator.free(webhook_dir_path);
    const mode: u32 = 0o755;
    if (std.posix.mkdir(webhook_dir_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }

    const json_string = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(webhook_details, .{})});

    const webhook_name = utils.genHash(json_string);
    const webhook_absolute_path = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ webhook_dir_path, webhook_name });
    defer allocator.free(json_string);
    defer allocator.free(webhook_absolute_path);
    std.log.info("file path: {s}", .{webhook_absolute_path});
    const file = try std.fs.createFileAbsolute(webhook_absolute_path, .{ .mode = mode });
    defer file.close();
    try file.writeAll(json_string);

    std.log.info("wrote webhook details {s} to file: ", .{webhook_name});
}

pub fn deleteWebhook(webhook_id: i32, allocator: std.mem.Allocator) !void {
    var webhook_list = try WebhookList.load(allocator);
    webhook_list.sortByUrl();
    std.log.info("webhook_id, {d}", .{webhook_id});
    defer webhook_list.deinit();

    const data_path = try xdg.getDataPath(allocator);
    const webhook_dir_path = try std.fmt.allocPrint(allocator, "{s}/webhooks", .{data_path});
    defer allocator.free(data_path);
    defer allocator.free(webhook_dir_path);

    const webhook_details = webhook_list.items[@intCast(webhook_id)];
    const json_string = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(webhook_details, .{})});
    const webhook_name = utils.genHash(json_string);
    const webhook_absolute_path = try std.fmt.allocPrint(allocator, "{s}/{s}.json", .{ webhook_dir_path, webhook_name });
    defer allocator.free(json_string);
    defer allocator.free(webhook_absolute_path);

    try std.fs.deleteFileAbsolute(webhook_absolute_path);
    std.log.info("Webhook details deleted!", .{});
}

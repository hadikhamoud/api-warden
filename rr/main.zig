const std = @import("std");
const rest_methods = @import("rest.zig");
const xdg = @import("paths.zig");
const logger = @import("logger.zig");
const utils = @import("utils.zig");

pub const std_options = logger.std_options;

const WebhookDetails = struct { url: []const u8, headers: []std.http.Header };

fn startProcess(arguments: [][:0]u8, alloc: std.mem.Allocator) !i32 {
    var child = std.process.Child.init(arguments, alloc);
    _ = try child.spawnAndWait();
    return child.id;
}

pub fn writeWebhookDetails(webhook_details: WebhookDetails, alloc: std.mem.Allocator) !void {
    const data_path = try xdg.getDataPath(alloc);
    const webhook_dir_path = try std.fmt.allocPrint(alloc, "{s}/webhooks", .{data_path});
    defer alloc.free(data_path);
    defer alloc.free(webhook_dir_path);
    const mode: u32 = 0o755;
    if (std.posix.mkdir(webhook_dir_path, mode)) |_| {} else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    }

    const json_string = try std.fmt.allocPrint(alloc, "{f}", .{std.json.fmt(webhook_details, .{})});

    const webhook_name = utils.genHash(json_string);
    const webhook_absolute_path = try std.fmt.allocPrint(alloc, "{s}/{s}.json", .{ webhook_dir_path, webhook_name });
    defer alloc.free(json_string);
    defer alloc.free(webhook_absolute_path);
    std.log.info("file path: {s}", .{webhook_absolute_path});
    const file = try std.fs.createFileAbsolute(webhook_absolute_path, .{ .mode = mode });
    defer file.close();
    try file.writeAll(json_string);

    std.log.info("wrote webhook details {s} to file: ", .{webhook_name});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Error", .{});
        return;
    }

    try xdg.initializeWardenFiles(allocator);
    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "get")) {
        const url = args[2];
        const response = try rest_methods.get(url, allocator);
        defer allocator.free(response);
        std.log.info("{s}", .{response});
    } else if (std.mem.eql(u8, cmd, "run")) {
        const arguments = args[2..args.len];
        const pid = try startProcess(arguments, allocator);
        std.log.info("process ID: {d}\n", .{pid});
    } else if (std.mem.eql(u8, cmd, "post")) {
        const headers = &[_]std.http.Header{
            .{ .name = "X-API-Key", .value = "" },
            .{ .name = "Content-Type", .value = "application/json" },
        };

        const url = args[2];
        const body = if (args.len > 3) args[3] else "";
        const response = try rest_methods.post(url, headers, body, allocator);
        defer allocator.free(response);
        std.log.info("{s}", .{response});
    } else if (std.mem.eql(u8, cmd, "set-webhook")) {
        if (args.len < 3) {
            std.log.err("you didn't provide any arguments buddy", .{});
            return;
        }

        const url = args[2];
        const headers_str = if (args.len > 3) args[3] else "";
        const headers_json = try std.json.parseFromSlice(std.json.Value, allocator, headers_str, .{});
        defer headers_json.deinit();
        var headers = try std.ArrayList(std.http.Header).initCapacity(allocator, 1024);
        defer headers.deinit(allocator);
        var it = headers_json.value.object.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const value = entry.value_ptr.*.string;
            try headers.append(allocator, .{ .name = name, .value = value });
        }

        std.log.info("Parsed url {s}:\n", .{url});
        std.log.info("Parsed headers:\n", .{});

        for (headers.items) |h| {
            std.log.info("{s}: {s}\n", .{ h.name, h.value });
        }

        const webhook_details = WebhookDetails{
            .url = url,
            .headers = headers.items,
        };
        _ = try writeWebhookDetails(webhook_details, allocator);

        std.log.info("WebhookDetails created with {d} headers\n", .{webhook_details.headers.len});
    } else {
        std.log.info("\nWrite a command", .{});
    }
    return;
}

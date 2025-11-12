const std = @import("std");
const rest_methods = @import("rest.zig");
const xdg = @import("paths.zig");
const logger = @import("logger.zig");
const utils = @import("utils.zig");
const builtin = @import("builtin");
const time = @import("datetime.zig");

pub const std_options = logger.std_options;

const WebhookDetails = struct { url: []const u8, headers: []std.http.Header };

const WebhookList = struct {
    items: []WebhookDetails,
    parsed_objects: []std.json.Parsed(WebhookDetails),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *WebhookList) void {
        for (self.parsed_objects) |parsed| {
            parsed.deinit();
        }
        self.allocator.free(self.parsed_objects);
        self.allocator.free(self.items);
    }
};

const ProcessResult = struct {
    pid: i32,
    exit_code: ?i32,
    interrupted: bool,
};

fn startProcess(arguments: [][:0]u8, alloc: std.mem.Allocator) !ProcessResult {
    var child = std.process.Child.init(arguments, alloc);
    try child.spawn();
    const pid = child.id;

    const term = child.wait() catch |err| {
        if (err == error.Unexpected) {
            return ProcessResult{
                .pid = pid,
                .exit_code = null,
                .interrupted = true,
            };
        }
        return err;
    };

    const exit_code: i32 = switch (term) {
        .Exited => |code| @intCast(code),
        .Signal => |sig| -@as(i32, @intCast(sig)),
        .Stopped => |sig| -@as(i32, @intCast(sig)),
        .Unknown => -1,
    };

    return ProcessResult{
        .pid = pid,
        .exit_code = exit_code,
        .interrupted = false,
    };
}

fn getWebhookDetails(alloc: std.mem.Allocator) !WebhookList {
    var webhooks = try std.ArrayList(WebhookDetails).initCapacity(alloc, 32);
    var parsed_list = try std.ArrayList(std.json.Parsed(WebhookDetails)).initCapacity(alloc, 32);

    const data_path = try xdg.getDataPath(alloc);
    const webhook_dir_path = try std.fmt.allocPrint(alloc, "{s}/webhooks", .{data_path});
    defer alloc.free(data_path);
    defer alloc.free(webhook_dir_path);
    var webhook_dir = try std.fs.openDirAbsolute(webhook_dir_path, .{ .iterate = true });
    defer webhook_dir.close();
    var webhook_dir_iterator = webhook_dir.iterate();
    while (try webhook_dir_iterator.next()) |dirContent| {
        if (dirContent.kind == .file) {
            const webhook_file = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ webhook_dir_path, dirContent.name });
            defer alloc.free(webhook_file);
            const file = try std.fs.openFileAbsolute(webhook_file, .{});
            defer file.close();
            const stat = try file.stat();
            const buffer: []u8 = try file.readToEndAlloc(alloc, stat.size);
            defer alloc.free(buffer);

            const parsed = try std.json.parseFromSlice(WebhookDetails, alloc, buffer, .{ .allocate = .alloc_always });
            try webhooks.append(alloc, parsed.value);
            try parsed_list.append(alloc, parsed);
        }
    }

    return WebhookList{
        .items = try webhooks.toOwnedSlice(alloc),
        .parsed_objects = try parsed_list.toOwnedSlice(alloc),
        .allocator = alloc,
    };
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
    const pid = switch (builtin.os.tag) {
        .linux => std.os.linux.getpid(),
        .windows => std.os.windows.kernel32.GetCurrentProcessId(),
        else => @compileError("Unsupported operating system"),
    };
    std.log.info("Current PID: {d}\n", .{pid});
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.info("Welcome to api-warden", .{});
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
        var webhook_list = try getWebhookDetails(allocator);
        defer webhook_list.deinit();
        std.log.info("received {d} webhooks", .{webhook_list.items.len});
        const result = try startProcess(arguments, allocator);
        std.log.info("process ID: {d}\n", .{result.pid});
        const full_command = try std.mem.join(allocator, " ", arguments);
        defer allocator.free(full_command);
        const payload = try std.fmt.allocPrint(allocator,
            \\{{
            \\  "event_type": "process_completed",
            \\  "data": {{
            \\    "process_id": {d},
            \\    "command": "{s}"
            \\  }}
            \\}}
        , .{ result.pid, full_command });
        defer allocator.free(payload);
        for (webhook_list.items) |webhook| {
            std.log.info("calling webhook {s}", .{webhook.url});
            const response = try rest_methods.post(webhook.url, webhook.headers, payload, allocator);
            defer allocator.free(response);
        }
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
        std.log.info("url: {s}", .{url});
        const headers_str = if (args.len > 3) args[3] else "";
        std.log.info("headers: {s}", .{headers_str});
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
        const arguments = args[1..args.len];
        var webhook_list = try getWebhookDetails(allocator);
        defer webhook_list.deinit();
        std.log.info("received {d} webhooks", .{webhook_list.items.len});
        var timer = try std.time.Timer.start();
        const result = try startProcess(arguments, allocator);
        const end = timer.read();
        var buf: [32]u8 = undefined;
        const time_taken = try utils.nanosecondsToHoursBuf(end, &buf);

        std.log.info("Time taken {s}", .{time_taken});
        std.log.info("process ID: {d}\n", .{result.pid});
        const full_command = try std.mem.join(allocator, " ", arguments);
        defer allocator.free(full_command);
        const payload = try std.fmt.allocPrint(allocator,
            \\{{
            \\  "event_type": "process_completed",
            \\  "data": {{
            \\    "time_taken": "{s}",
            \\    "process_id": {d},
            \\    "command": "{s}"
            \\  }}
            \\}}
        , .{ time_taken, result.pid, full_command });
        defer allocator.free(payload);
        for (webhook_list.items) |webhook| {
            std.log.info("calling webhook {s}", .{webhook.url});
            const response = try rest_methods.post(webhook.url, webhook.headers, payload, allocator);
            defer allocator.free(response);
        }
    }
    return;
}

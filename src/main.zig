const std = @import("std");
const rest_methods = @import("rest.zig");
const xdg = @import("paths.zig");
const logger = @import("logger.zig");
const utils = @import("utils.zig");
const builtin = @import("builtin");
const time = @import("datetime.zig");
const webhooks = @import("webhooks.zig");
const build_options = @import("build_options");

pub const std_options = logger.std_options;

const WebhookDetails = webhooks.WebhookDetails;
const WebhookList = webhooks.WebhookList;

const ProcessResult = struct {
    pid: i32,
    exit_code: ?i32,
    interrupted: bool,
    stderr: []const u8,
};

fn startProcess(arguments: [][:0]u8, alloc: std.mem.Allocator) !ProcessResult {
    var child = std.process.Child.init(arguments, alloc);
    child.stderr_behavior = .Pipe;
    child.stdout_behavior = .Inherit;
    child.spawn() catch |err| {
        if (err == error.FileNotFound) {
            const stderr_msg = try std.fmt.allocPrint(alloc, "Command not found: {s}", .{arguments[0]});
            std.log.err("Command not found: {s}", .{arguments[0]});
            return ProcessResult{
                .pid = -1,
                .exit_code = 127,
                .interrupted = false,
                .stderr = stderr_msg,
            };
        }
        return err;
    };
    const pid = child.id;

    const max_output_size = 10 * 1024 * 1024;
    const stderr = try child.stderr.?.readToEndAlloc(alloc, max_output_size);

    const term = child.wait() catch |err| {
        if (err == error.FileNotFound) {
            const stderr_msg = try std.fmt.allocPrint(alloc, "Command not found: {s}", .{arguments[0]});
            std.log.err("Command not found: {s}", .{arguments[0]});
            return ProcessResult{
                .pid = -1,
                .exit_code = 127,
                .interrupted = false,
                .stderr = stderr_msg,
            };
        }
        if (err == error.Unexpected) {
            return ProcessResult{
                .pid = pid,
                .exit_code = null,
                .interrupted = true,
                .stderr = stderr,
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
        .stderr = stderr,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const pid = switch (builtin.os.tag) {
        .linux => std.os.linux.getpid(),
        .macos => std.c.getpid(),
        .windows => std.os.windows.GetCurrentProcessId(),
        else => @compileError("Unsupported operating system"),
    };
    std.log.info("Current PID: {d}", .{pid});
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.info("Welcome to api-warden", .{});
        return;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "version") or
        std.mem.eql(u8, cmd, "--version") or
        std.mem.eql(u8, cmd, "-v"))
    {
        std.debug.print("api-warden version {s}\n", .{build_options.version});
        return;
    }

    if (std.mem.eql(u8, cmd, "help") or
        std.mem.eql(u8, cmd, "--help") or
        std.mem.eql(u8, cmd, "-h"))
    {
        std.debug.print("API WARDEN\n", .{});
        std.debug.print("need help?\n", .{});
        std.debug.print("just run a command after `api-warden`. ex: api-warden echo hello world\n", .{});
        std.debug.print("set a webhook endpoint with headers using `set-webhook`. ex: api-warden set-webhook <url-endpoint> {{\"Authorization\": \"Bearer <token>\"}}\n", .{});
        std.debug.print("list webhooks using `list-webhook`. ex: api-warden list-webhook\n", .{});
        std.debug.print("after listing them, you can delete them using the ids by using `delete-webhook`. ex: api-warden delete-webhook <id>\n", .{});
        return;
    }

    try xdg.initializeWardenFiles(allocator);
    if (std.mem.eql(u8, cmd, "get")) {
        const url = args[2];
        const response = try rest_methods.get(url, allocator);
        defer allocator.free(response);
        std.log.info("{s}", .{response});
    } else if (std.mem.eql(u8, cmd, "run")) {
        const arguments = args[2..args.len];
        var webhook_list = try WebhookList.load(allocator);
        webhook_list.sortByUrl();
        defer webhook_list.deinit();
        std.log.info("received {d} webhooks", .{webhook_list.items.len});
        const result = try startProcess(arguments, allocator);
        defer allocator.free(result.stderr);
        if (result.pid > 0) {
            std.log.info("process ID: {d}\n", .{result.pid});
        }
        const full_command = try std.mem.join(allocator, " ", arguments);
        defer allocator.free(full_command);

        const exit_code = result.exit_code orelse -999;
        const payload = if (exit_code != 0)
            try std.fmt.allocPrint(allocator,
                \\{{
                \\  "event_type": "process_completed",
                \\  "data": {{
                \\    "process_id": {d},
                \\    "command": "{s}",
                \\    "exit_code": {d},
                \\    "stderr": "{s}"
                \\  }}
                \\}}
            , .{ result.pid, full_command, exit_code, result.stderr })
        else
            try std.fmt.allocPrint(allocator,
                \\{{
                \\  "event_type": "process_completed",
                \\  "data": {{
                \\    "process_id": {d},
                \\    "command": "{s}",
                \\    "exit_code": {d}
                \\  }}
                \\}}
            , .{ result.pid, full_command, exit_code });
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
        _ = try webhooks.writeWebhookDetails(webhook_details, allocator);

        std.log.info("WebhookDetails created with {d} headers\n", .{webhook_details.headers.len});
    } else if (std.mem.eql(u8, cmd, "list-webhooks")) {
        var webhook_list = try WebhookList.load(allocator);
        defer webhook_list.deinit();
        for (webhook_list.items, 0..) |webhook, index| {
            std.debug.print("\nWebhook {d}:\n", .{index});
            std.debug.print("url: {s}\n", .{webhook.url});
            std.debug.print("headers: \n", .{});
            for (webhook.headers) |header| {
                std.debug.print("\t {s}: {s}\n", .{ header.name, header.value });
            }
        }
    } else if (std.mem.eql(u8, cmd, "delete-webhook")) {
        if (args.len < 2) {
            std.log.err("Please specify which webhook id you want to delete", .{});
            return;
        }
        const selected_id: i32 = try std.fmt.parseInt(i32, args[2], 10);
        try webhooks.deleteWebhook(selected_id, allocator);
    } else {
        const arguments = args[1..args.len];
        var webhook_list = try WebhookList.load(allocator);
        defer webhook_list.deinit();
        std.log.info("received {d} webhooks", .{webhook_list.items.len});
        var timer = try std.time.Timer.start();
        const result = try startProcess(arguments, allocator);
        defer allocator.free(result.stderr);
        const end = timer.read();
        var buf: [32]u8 = undefined;
        const time_taken = try utils.nanosecondsToHoursBuf(end, &buf);

        std.log.info("Time taken {s}", .{time_taken});
        if (result.pid > 0) {
            std.log.info("process ID: {d}\n", .{result.pid});
        }
        const full_command = try std.mem.join(allocator, " ", arguments);
        defer allocator.free(full_command);

        const exit_code = result.exit_code orelse -999;
        const payload = if (exit_code != 0)
            try std.fmt.allocPrint(allocator,
                \\{{
                \\  "event_type": "process_completed",
                \\  "data": {{
                \\    "time_taken": "{s}",
                \\    "process_id": {d},
                \\    "command": "{s}",
                \\    "exit_code": {d},
                \\    "stderr": "{s}"
                \\  }}
                \\}}
            , .{ time_taken, result.pid, full_command, exit_code, result.stderr })
        else
            try std.fmt.allocPrint(allocator,
                \\{{
                \\  "event_type": "process_completed",
                \\  "data": {{
                \\    "time_taken": "{s}",
                \\    "process_id": {d},
                \\    "command": "{s}",
                \\    "exit_code": {d}
                \\  }}
                \\}}
            , .{ time_taken, result.pid, full_command, exit_code });
        defer allocator.free(payload);
        for (webhook_list.items) |webhook| {
            std.log.info("calling webhook {s}", .{webhook.url});
            const response = try rest_methods.post(webhook.url, webhook.headers, payload, allocator);
            defer allocator.free(response);
        }
    }
    return;
}

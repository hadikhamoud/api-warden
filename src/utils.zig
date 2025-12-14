const std = @import("std");
const rest = @import("rest.zig");
const xdg = @import("paths.zig");
const build_options = @import("build_options");

pub fn genHash(bytes: []const u8) [32]u8 {
    var hash: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(bytes, &hash, .{});

    var out: [32]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{s}", .{std.fmt.bytesToHex(hash, .lower)}) catch unreachable;
    return out;
}

pub fn nanosecondsToHoursBuf(time_in_nano: u64, buf: []u8) ![]const u8 {
    const total_seconds = @divFloor(time_in_nano, 1000000000);
    const seconds = @mod(total_seconds, 60);
    const total_minutes = @divFloor(total_seconds, 60);
    const minutes = @mod(total_minutes, 60);
    const hours = @divFloor(total_minutes, 60);

    const remaining_nanos = @mod(time_in_nano, 1000000000);
    const microseconds = @divFloor(remaining_nanos, 1000);
    const nanoseconds = @mod(remaining_nanos, 1000);

    return try std.fmt.bufPrint(buf, "{d:0>2}:{d:0>2}:{d:0>2}.{d:0>6}.{d:0>3}", .{ hours, minutes, seconds, microseconds, nanoseconds });
}

pub const SemverOrder = enum {
    greater,
    equal,
    less,
};

pub fn compareSemvers(a: []const u8, b: []const u8) !SemverOrder {
    const parts_a = try parseSemver(a);
    const parts_b = try parseSemver(b);

    inline for (0..3) |i| {
        if (parts_a[i] > parts_b[i]) return .greater;
        if (parts_a[i] < parts_b[i]) return .less;
    }
    return .equal;
}

fn parseSemver(version: []const u8) ![3]u32 {
    const without_v = if (version.len > 0 and version[0] == 'v') version[1..] else version;

    const clean = if (std.mem.indexOfScalar(u8, without_v, '-')) |idx| without_v[0..idx] else without_v;

    var parts: [3]u32 = undefined;
    var iter = std.mem.splitSequence(u8, clean, ".");

    inline for (0..3) |i| {
        const part = iter.next() orelse return error.InvalidSemver;
        parts[i] = std.fmt.parseInt(u32, part, 10) catch return error.InvalidSemver;
    }
    return parts;
}

fn getRemoteVersion(alloc: std.mem.Allocator) ![]const u8 {
    const URL = "https://api.github.com/repos/hadikhamoud/api-warden/releases/latest";
    const response = try rest.get(URL, alloc);

    const parsed = try std.json.parseFromSlice(struct { tag_name: []const u8 }, alloc, response, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    return try alloc.dupe(u8, parsed.value.tag_name);
}

fn downloadNewVersion(alloc: std.mem.Allocator) !bool {
    const URL = "https://raw.githubusercontent.com/hadikhamoud/api-warden/main/install.sh";
    const response = try rest.get(URL, alloc);
    const data_path = try xdg.getDataPath(alloc);

    const install_script_path = try std.fmt.allocPrint(alloc, "{s}/install.sh", .{data_path});
    defer alloc.free(data_path);
    defer alloc.free(install_script_path);
    const mode: u32 = 0o755;

    const file = try std.fs.createFileAbsolute(install_script_path, .{ .mode = mode });
    defer file.close();
    try file.writeAll(response);

    std.log.info("received install instructions to file: ", .{});

    var child = std.process.Child.init(&[_][]const u8{ "/bin/bash", install_script_path }, alloc);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.stdin_behavior = .Inherit;
    _ = try child.spawnAndWait();

    std.log.info("downloaded new version", .{});
    return true;
}

pub fn update(alloc: std.mem.Allocator) !bool {
    const curr_version = build_options.version;
    const remote_version = try getRemoteVersion(alloc);
    if (try compareSemvers(curr_version, remote_version) == .less) {
        return downloadNewVersion(alloc);
    }
    return false;
}

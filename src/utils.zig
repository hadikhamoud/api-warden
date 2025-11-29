const std = @import("std");

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

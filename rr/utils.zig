const std = @import("std");

pub fn genHash(bytes: []const u8) [32]u8 {
    var hash: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(bytes, &hash, .{});

    var out: [32]u8 = undefined;
    _ = std.fmt.bufPrint(&out, "{s}", .{std.fmt.bytesToHex(hash, .lower)}) catch unreachable;
    return out;
}

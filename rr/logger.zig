const std = @import("std");
const time = @import("datetime.zig");

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = structLogFn,
};

pub fn structLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] ";

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    var stderr = std.fs.File.stderr().writer(&.{});
    const timestamp = time.Datetime.now();
    var buf: [32]u8 = undefined;
    const timestamp_str = timestamp.formatHttpBuf(&buf) catch "INVALID_TIME";

    nosuspend stderr.interface.print(prefix ++ "{s} " ++ scope_prefix ++ format ++ "\n", .{timestamp_str} ++ args) catch return;
}

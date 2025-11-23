const std = @import("std");

fn getVersion(b: *std.Build) []const u8 {
    var exit_code: u8 = undefined;
    const result = b.runAllowFail(
        &[_][]const u8{
            "git",
            "describe",
            "--tags",
            "--always",
            "--dirty",
        },
        &exit_code,
        .Ignore,
    ) catch {
        return "unknown";
    };

    return std.mem.trim(u8, result, " \n\r\t");
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get version from git
    const version = getVersion(b);

    // Define the executable
    const exe = b.addExecutable(.{
        .name = "api-warden",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add version as a build option
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    exe.root_module.addImport("build_options", options.createModule());

    b.installArtifact(exe);

    // Run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test step
    const exe_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    configureTests(b, target, optimize);
    configureCommand(b, target, optimize);
}

fn configureTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const main_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const arm_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/arm7tdmi/arm7tdmi.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("arm", arm_module);

    const ctest_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/ctest.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_module.addImport("ctest", ctest_module);

    const tests = b.addTest(.{
        .root_module = main_module,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_tests.step);
}

fn configureCommand(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const exe = b.addExecutable(.{
        .name = "cartographer",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run cartographer");
    run_step.dependOn(&run_cmd.step);
}

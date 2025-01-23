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
    arm_module.addImport("ctest", ctest_module);

    const main_tests = b.addTest(.{
        .root_module = main_module,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    const arm_tests = b.addTest(.{
        .root_module = arm_module,
    });
    const run_arm_tests = b.addRunArtifact(arm_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_arm_tests.step);
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

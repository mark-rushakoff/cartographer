const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // blip_buf is an external dependency of mGBA,
    // presumably due to it being LGPL.
    const blip_buf_dep = b.dependency("blip_buf", .{
        .target = target,
        .optimize = optimize,
    });

    const blip_buf_lib = b.addStaticLibrary(.{
        .name = "blip_buf",
        .target = target,
        .optimize = optimize,
    });

    const blip_buf_source_files = [_][]const u8{
        "blip_buf.c",
    };
    for (blip_buf_source_files) |src| {
        blip_buf_lib.addCSourceFile(.{
            .file = blip_buf_dep.path(src),
            .flags = &[_][]const u8{"-std=c99"},
        });
    }
    blip_buf_lib.linkLibC();
    b.installArtifact(blip_buf_lib);

    const mgba_dep = b.dependency("mgba", .{
        .target = target,
        .optimize = optimize,
    });

    const include_path = mgba_dep.path("include");
    const src_path = mgba_dep.path("src");

    const mgba_lib = b.addStaticLibrary(.{
        .name = "mgba",
        .target = target,
        .optimize = optimize,
    });

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();

    try c_flags.append("-std=c99");

    switch (target.result.os.tag) {
        .macos => {
            try c_flags.append("-DHAVE_STRLCPY");
        },
        else => {},
    }

    mgba_lib.addIncludePath(include_path);
    mgba_lib.addIncludePath(src_path);

    // In mGBA, this file would be filled in through CMake.
    // Zig expects us to know the replace values at comptime,
    // so that is why we read it in and do the literal string replaces.
    const mgba_version_template = mgba_dep.path("src/core/version.c.in");

    const template_contents = std.fs.cwd().readFileAlloc(b.allocator, mgba_version_template.getPath(b), std.math.maxInt(usize)) catch unreachable;

    var processed_version = std.mem.replaceOwned(u8, b.allocator, template_contents, "${GIT_COMMIT}", "unknown") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${GIT_COMMIT_SHORT}", "unknown") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${GIT_BRANCH}", "unknown") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${GIT_REV}", "0") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${BINARY_NAME}", "cartographer") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${PROJECT_NAME}", "cartographer") catch unreachable;
    processed_version = std.mem.replaceOwned(u8, b.allocator, processed_version, "${VERSION_STRING}", "0.0.1") catch unreachable;

    const version_file = b.addWriteFile("version.c", processed_version);
    mgba_lib.addCSourceFile(.{
        .file = version_file.getDirectory().path(b, "version.c"),
        .flags = c_flags.items,
    });

    // There is probably a better way to include the mGBA source files in the build.
    // This list was mostly driven by responding to compile errors about missing symbols.
    const mgba_source_files = [_][]const u8{
        "src/arm/arm.c",
        "src/arm/decoder.c",
        "src/arm/decoder-arm.c",
        "src/arm/decoder-thumb.c",
        "src/arm/isa-arm.c",
        "src/arm/isa-thumb.c",

        "src/core/bitmap-cache.c",
        "src/core/cache-set.c",
        "src/core/cheats.c",
        "src/core/config.c",
        "src/core/core.c",
        "src/core/directories.c",
        "src/core/interface.c",
        "src/core/log.c",
        "src/core/map-cache.c",
        "src/core/serialize.c",
        "src/core/sync.c",
        "src/core/timing.c",
        "src/core/tile-cache.c",

        "src/gb/audio.c",

        "src/gba/audio.c",
        "src/gba/bios.c",
        "src/gba/cheats.c",
        "src/gba/core.c",
        "src/gba/dma.c",
        "src/gba/gba.c",
        "src/gba/hle-bios.c",
        "src/gba/io.c",
        "src/gba/memory.c",
        "src/gba/overrides.c",
        "src/gba/savedata.c",
        "src/gba/serialize.c",
        "src/gba/sio.c",
        "src/gba/timer.c",
        "src/gba/video.c",

        "src/gba/cart/ereader.c",
        "src/gba/cart/gpio.c",
        "src/gba/cart/matrix.c",
        "src/gba/cart/vfame.c",

        "src/gba/cheats/codebreaker.c",
        "src/gba/cheats/gameshark.c",
        "src/gba/cheats/parv3.c",

        "src/gba/extra/audio-mixer.c",
        "src/gba/extra/proxy.c",

        "src/gba/renderers/cache-set.c",
        "src/gba/renderers/common.c",
        "src/gba/renderers/software-bg.c",
        "src/gba/renderers/software-mode0.c",
        "src/gba/renderers/software-obj.c",
        "src/gba/renderers/video-software.c",

        "src/gba/sio/gbp.c",

        "src/util/circle-buffer.c",
        "src/util/configuration.c",
        "src/util/crc32.c",
        "src/util/formatting.c",
        "src/util/gbk-table.c",
        "src/util/hash.c",
        "src/util/memory.c",
        "src/util/patch.c",
        "src/util/patch-ips.c",
        "src/util/patch-ups.c",
        "src/util/string.c",
        "src/util/table.c",
        "src/util/vfs.c",

        "src/util/vfs/vfs-dirent.c",
        "src/util/vfs/vfs-fd.c",
        "src/util/vfs/vfs-mem.c",

        "src/feature/video-logger.c",

        "src/third-party/inih/ini.c",
    };

    for (mgba_source_files) |src| {
        mgba_lib.addCSourceFile(.{
            .file = mgba_dep.path(src),
            .flags = c_flags.items,
        });
    }

    mgba_lib.linkLibrary(blip_buf_lib);

    mgba_lib.linkLibC();

    const exe = b.addExecutable(.{
        .name = "cartographer",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(include_path);
    exe.addIncludePath(src_path);
    exe.linkLibC();
    exe.linkLibrary(mgba_lib);

    // Ensure correct system frameworks are linked.
    switch (target.result.os.tag) {
        .macos => {
            mgba_lib.linkFramework("CoreFoundation");
            exe.linkFramework("CoreFoundation");
        },
        else => {},
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}

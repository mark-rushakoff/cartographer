const MemoryManager = @import("./MemoryManager.zig");
const MemoryRegion = @import("./MemoryRegion.zig");
const BufferRegion = @import("./memory/regions/Buffer.zig").Buffer;
const testing = @import("std").testing;

test "setPipelineOperation sets active operation to pipeline" {
    var mm = MemoryManager.initial;

    // Begins idle.
    try testing.expectEqual(.idle, mm.active_operation);

    mm.setPipelineOperation(.{
        .read_half = 0x0000_1234,
    });
    try testing.expectEqual(.pipeline, mm.active_operation);
}

test "setCpuOperation sets active operation to cpu" {
    var mm = MemoryManager.initial;

    // Begins idle.
    try testing.expectEqual(.idle, mm.active_operation);

    mm.setCpuOperation(.{
        .read_half = 0x0000_9876,
    });
    try testing.expectEqual(.cpu, mm.active_operation);
}

test "setPipelineOperation takes active precedence over CPU" {
    var mm = MemoryManager.initial;

    // Begins idle.
    try testing.expectEqual(.idle, mm.active_operation);

    // CPU operation.
    mm.setCpuOperation(.{
        .read_word = 0x0000_9876,
    });
    try testing.expectEqual(.cpu, mm.active_operation);

    // Same tick, the pipeline fetches, and it takes over the active operation.
    mm.setPipelineOperation(.{
        .read_half = 0x0000_1234,
    });
    try testing.expectEqual(.pipeline, mm.active_operation);
}

test "setCpuOperation does not take precedence over pipeline operation" {
    var mm = MemoryManager.initial;

    mm.setPipelineOperation(.{
        .read_half = 0x0000_1234,
    });
    try testing.expectEqual(.pipeline, mm.active_operation);

    mm.setCpuOperation(.{
        .read_half = 0x0000_9876,
    });

    // Still active pipeline.
    try testing.expectEqual(.pipeline, mm.active_operation);
}

test "tick with no active operation returns null" {
    var mm = MemoryManager.initial;
    try testing.expectEqual(null, mm.tick());
}

const Buf8 = BufferRegion(8, 0);

test "ticking an active pipeline half read returns a completion, on BIOS region with wait=1" {
    var mm = MemoryManager.initial;
    var biosRegion = Buf8{
        .data = .{ 0xab, 0x12 } ++ (.{0} ** 6),
    };
    const bios = MemoryRegion.init(&biosRegion);
    const regions = MemoryManager.Regions{
        .bios = bios,
    };
    mm.regions = regions;

    mm.setPipelineOperation(.{
        .read_half = 0x0000_0000,
    });
    const comp = mm.tick();
    try testing.expectEqual(MemoryManager.Completion{
        .pipeline = .{
            .read_half = 0x12ab,
        },
    }, comp.?);
}

test "ticking an active pipeline word read returns a completion, on BIOS region with wait=1" {
    var mm = MemoryManager.initial;
    var biosRegion = Buf8{
        .data = .{ 0xcd, 0xab, 0x34, 0x12 } ++ (.{0} ** 4),
    };
    const bios = MemoryRegion.init(&biosRegion);
    const regions = MemoryManager.Regions{
        .bios = bios,
    };
    mm.regions = regions;

    mm.setPipelineOperation(.{
        .read_word = 0x0000_0000,
    });
    const comp = mm.tick();
    try testing.expectEqual(MemoryManager.Completion{
        .pipeline = .{
            .read_word = 0x1234_abcd,
        },
    }, comp.?);
}

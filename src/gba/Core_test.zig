const arm = @import("arm7tdmi");
const Core = @import("./Core.zig");
const MemoryManager = @import("./MemoryManager.zig");
const MemoryRegion = @import("./MemoryRegion.zig");
const BufferRegion = @import("./memory/regions/Buffer.zig").Buffer;
const testing = @import("std").testing;

fn testingCore(memory_manager: MemoryManager) !Core {
    const registers = arm.Registers.initial;

    return Core{
        .registers = registers,

        .cpu = arm.Cpu{
            // TODO: this might not be the appropriate starting status.
            .status = .ready,
        },

        .pipeline = arm.Pipeline.init(registers.state()),

        .memory_manager = memory_manager,

        .cycle_count = 0,
    };
}

test "tick increases cycle count by 1" {
    var bios_impl = BufferRegion(8, 0){
        .data = .{0} ** 8,
    };
    var mm = MemoryManager.initial;
    mm.regions = .{
        .bios = MemoryRegion.init(&bios_impl),
    };

    var core = try testingCore(mm);

    try testing.expectEqual(0, core.cycle_count);
    core.tick();
    try testing.expectEqual(1, core.cycle_count);
}

test "initial tick sets memory manager state" {
    var bios_impl = BufferRegion(8, 0){
        .data = .{0} ** 8,
    };
    var mm = MemoryManager.initial;
    mm.regions = .{
        .bios = MemoryRegion.init(&bios_impl),
    };

    var core = try testingCore(mm);

    // Before first tick:
    // Memory manager is idle.
    try testing.expectEqual(.idle, core.memory_manager.active_operation);
    try testing.expectEqual(null, core.memory_manager.pending_pipeline);
    try testing.expectEqual(null, core.memory_manager.pending_cpu);

    core.tick();

    // Now memory manager is pending on pipeline.
    try testing.expectEqual(.pipeline, core.memory_manager.active_operation);
    try testing.expectEqual(MemoryManager.PendingRo{
        // r15 starts at zero,
        // and CPU starts in ARM, not THUMB.
        .read_word = 0,
    }, core.memory_manager.pending_pipeline);
    try testing.expectEqual(null, core.memory_manager.pending_cpu);

    // Tick again and the pending pipeline operation completes.
    core.tick();

    // Which means the pipeline is fetching the next instruction,
    // and decoding the first one.
    try testing.expectEqual(arm.Pipeline.FetchState{ .pending_word = 4 }, core.pipeline.fetch_state);
    try testing.expectEqual(arm.Pipeline.DecodingValue{ .arm = 0 }, core.pipeline.decoding_value);

    // TODO: tick again to ready
}

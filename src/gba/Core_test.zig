const arm = @import("arm7tdmi");
const Core = @import("./Core.zig");
const MemoryManager = @import("./MemoryManager.zig");
const testing = @import("std").testing;

fn testingCore() Core {
    const reg = arm.Registers.initial;
    return Core{
        .registers = reg,

        .cpu = arm.Cpu{
            // TODO: this might not be the appropriate starting status.
            .status = .ready,
        },

        .pipeline = arm.Pipeline.init(reg.state()),

        .memory_manager = MemoryManager.initial,

        .cycle_count = 0,
    };
}

test "tick increases cycle count by 1" {
    var core = testingCore();

    try testing.expectEqual(0, core.cycle_count);
    core.tick();
    try testing.expectEqual(1, core.cycle_count);
}

test "initial tick sets memory manager state" {
    var core = testingCore();

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
}

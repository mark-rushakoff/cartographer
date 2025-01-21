const arm = @import("arm");

/// Core contains all the hardware of a GBA.
pub const Core = struct {
    /// The registers stand alone within the core,
    /// in order for the pipeline and CPU to access them independently.
    registers: arm.Registers,

    cpu: arm.Cpu,

    pipeline: arm.Pipeline,

    // TODO: memory, DMA controller, prefetch buffer

    // At 16.78MHz, it would take about 35 years to overflow the cycle count,
    // so a u64 seems completely appropriate here.
    cycle_count: u64,

    pub fn tick(self: *Core) void {
        // TODO: actually delegate ticks to components.

        self.cycle_count += 1;
    }
};

const testing = @import("std").testing;

fn testingCore() Core {
    return Core{
        .registers = arm.Registers.initial,

        .cpu = arm.Cpu{
            // TODO: this might not be the appropriate starting status.
            .status = .ready,
        },

        .pipeline = arm.Pipeline{},

        .cycle_count = 0,
    };
}

test "tick increases cycle count by 1" {
    var core = testingCore();

    try testing.expectEqual(0, core.cycle_count);
    core.tick();
    try testing.expectEqual(1, core.cycle_count);
}

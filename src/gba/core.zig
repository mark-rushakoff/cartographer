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

    /// The tick method causes one full clock cycle
    /// to be propagated to all the components within the core.
    ///
    /// As the Core type is the primary external-facing API,
    /// we only expose a single tick method here.
    /// However, the components within the Core have both
    /// `tick_rising` and `tick_falling` methods.
    /// This is intended to capture the subtle timing involved
    /// within the processor clock, where different things happen
    /// as part of the rising edge versus the falling edge of a clock cycle.
    ///
    /// Chapter 6 of the ARM7TDMI data sheet contains significant detail.
    pub fn tick(self: *Core) void {
        // TODO: delegate to more components.

        self.pipeline.tick(self.registers.r15);

        self.cycle_count += 1;
    }
};

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

        .cycle_count = 0,
    };
}

test "tick increases cycle count by 1" {
    var core = testingCore();

    try testing.expectEqual(0, core.cycle_count);
    core.tick();
    try testing.expectEqual(1, core.cycle_count);
}

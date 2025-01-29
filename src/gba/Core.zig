const arm = @import("arm7tdmi");
const MemoryManager = @import("./MemoryManager.zig");

/// Core contains all the hardware of a GBA.
const Core = @This();

/// The registers stand alone within the core,
/// in order for the pipeline and CPU to access them independently.
registers: arm.Registers,

cpu: arm.Cpu,

pipeline: arm.Pipeline,

memory_manager: MemoryManager,

// TODO: memory, DMA controller, prefetch buffer

// At 16.78MHz, it would take about 35 years to overflow the cycle count,
// so a u64 seems completely appropriate here.
cycle_count: u64,

/// The tick method causes one full clock cycle
/// to be propagated to all the components within the core.
///
/// As the Core type is the primary external-facing API,
/// we only expose a single tick method here.
pub fn tick(self: *Core) void {
    // TODO: delegate to more components.

    const pipeline_was_fetch_pending = switch (self.pipeline.fetch_state) {
        .pending_half, .pending_word => true,
        else => false,
    };
    const pc = self.registers.r15;
    self.pipeline.tick(pc);
    if (!pipeline_was_fetch_pending) {
        // Did we switch from not pending to pending?
        switch (self.pipeline.fetch_state) {
            .pending_half => {
                self.memory_manager.setPipelineOperation(.{
                    .read_half = pc,
                });
            },
            .pending_word => {
                self.memory_manager.setPipelineOperation(.{
                    .read_word = pc,
                });
            },

            // Not pending before, not pending now.
            else => {},
        }
    }

    if (self.memory_manager.tick()) |comp| {
        switch (comp) {
            .pipeline => self.handlePipelineMemoryCompletion(comp.pipeline),
            .cpu => self.handleCpuMemoryCompletion(comp.cpu),
        }
    }

    self.cycle_count += 1;
}

fn handlePipelineMemoryCompletion(self: *Core, comp: MemoryManager.PipelineCompletion) void {
    switch (comp) {
        .read_half => self.pipeline.completeFetchHalf(comp.read_half, &self.registers.r15),
        .read_word => self.pipeline.completeFetchWord(comp.read_word, &self.registers.r15),
    }
}

fn handleCpuMemoryCompletion(self: *Core, comp: MemoryManager.CpuCompletion) void {
    // TODO.
    _ = self;
    _ = comp;
}

test {
    _ = @import("./core_test.zig");
}

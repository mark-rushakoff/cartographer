/// The MemoryManager handles bus arbitration, wait states,
/// and other details of the memory of the GBA.
pub const MemoryManager = @This();

active_operation: ActiveOperation,

waits_remaining: u8,

// Track the previously accessed address,
// to track if we need to wait for a sequential or non-sequential access.
prev_address: u32,

pending_pipeline: ?PendingRo,

pending_cpu: ?Pending,

pub const initial = MemoryManager{
    // If this was -1, then reading from 0 could be sequential,
    // so set it to -2, because the first read should never be from -1.
    .prev_address = 0xffff_fffe,
    .waits_remaining = 0xff,

    .active_operation = .idle,
    .pending_pipeline = null,
    .pending_cpu = null,
};

pub fn tick(self: *MemoryManager) ?Completion {
    _ = self;
    return null;
}

pub fn setPipelineOperation(self: *MemoryManager, op: PendingRo) void {
    if (self.pending_pipeline != null) {
        @panic("ILLEGAL: setPipelineOperation called when pending_pipeline was not null");
    }
    self.pending_pipeline = op;

    self.updateActiveOperation();
}

fn updateActiveOperation(self: *MemoryManager) void {
    switch (self.active_operation) {
        // Top priority until we respect DMA.
        .pipeline => return,

        // Only superseded by Pipeline.
        .cpu => {
            if (self.pending_pipeline != null) {
                self.active_operation = .pipeline;
                self.resetWaitCount();
                return;
            }
        },

        // Superseded by Pipeline, then CPU.
        .idle => {
            if (self.pending_pipeline != null) {
                self.active_operation = .pipeline;
                self.resetWaitCount();
                return;
            }

            if (self.pending_cpu != null) {
                self.active_operation = .cpu;
                self.resetWaitCount();
                return;
            }
        },
    }
}

fn resetWaitCount(self: *MemoryManager) void {
    // TODO: inspect operation and actually set this.
    self.waits_remaining = 2;
}

/// Type of active_operation field.
/// Ordered from lowest to highest priority.
pub const ActiveOperation = enum {
    idle,
    cpu,
    pipeline,
};

/// Pending read-only operation.
/// The u32 value is the memory address being read.
pub const PendingRo = union(enum) {
    read_byte: u32,
    read_half: u32,
    read_word: u32,
};

/// Pending read or write operation.
/// The read values' u32 indicates the address being read.
pub const Pending = union(enum) {
    read_byte: u32,
    read_half: u32,
    read_word: u32,

    write_byte: struct { addr: u32, val: u8 },
    write_half: struct { addr: u32, val: u16 },
    write_word: struct { addr: u32, val: u32 },
};

/// Returned as an optional from the tick method,
/// when a pending read or write has finished as of that tick.
pub const Completion = union(enum) {
    pipeline: PipelineCompletion,
    cpu: CpuCompletion,
};

/// Completion type when a Pipeline read completes.
pub const PipelineCompletion = union(enum) {
    read_half: u16,
    read_word: u32,
};

/// Completion type when a CPU read or write completes.
pub const CpuCompletion = union(enum) {
    read_byte: u8,
    read_half: u16,
    read_word: u32,

    write: void,
};

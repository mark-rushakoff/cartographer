const MemoryRegion = @import("./MemoryRegion.zig");

/// The MemoryManager handles bus arbitration, wait states,
/// and other details of the memory of the GBA.
pub const MemoryManager = @This();

active_operation: ActiveOperation,

waits_remaining: u8,

// Track the previously accessed address,
// to track if we need to wait for a sequential or non-sequential access.
prev_address: u32,

// This should probably be a different type with only
// read_half and read_word,
// as the read_byte => unreachable code adds a lot of clutter.
pending_pipeline: ?PendingRo,

pending_cpu: ?Pending,

regions: Regions,

pub const Regions = struct {
    bios: MemoryRegion,
};

const NullRegion = @import("./memory/regions/Null.zig");

pub const initial = MemoryManager{
    // If this was -1, then reading from 0 at startup could be considered sequential,
    // so set it to -2, because the first read should never be from -1.
    .prev_address = 0xffff_fffe,
    .waits_remaining = 0xff,

    .active_operation = .idle,
    .pending_pipeline = null,
    .pending_cpu = null,

    .regions = Regions{
        .bios = MemoryRegion.init(@constCast(&NullRegion{})),
    },
};

pub fn tick(self: *MemoryManager) ?Completion {
    if (self.active_operation == .idle) {
        // Nothing to do.
        return null;
    }

    // We do have an active operation.
    // If this was the last tick, just do the work,
    // skipping the decrement.
    if (self.waits_remaining == 1) {
        return self.completeOperation();
    }

    // We weren't completed, so decrement waits.
    self.waits_remaining -= 1;
    return null;
}

fn completeOperation(self: *MemoryManager) Completion {
    switch (self.active_operation) {
        // Must never be called when idle.
        .idle => unreachable,

        .pipeline => {
            switch (self.pending_pipeline.?) {
                // Pipeline can never read a byte.
                .read_byte => unreachable,

                .read_half => return .{
                    .pipeline = .{
                        .read_half = self.readHalfImmediate(self.pending_pipeline.?.read_half),
                    },
                },

                .read_word => return .{
                    .pipeline = .{
                        .read_word = self.readWordImmediate(self.pending_pipeline.?.read_word),
                    },
                },
            }
        },

        .cpu => @panic("TODO: handle completing CPU operation"),
    }
}

pub fn setPipelineOperation(self: *MemoryManager, op: PendingRo) void {
    if (self.pending_pipeline != null) {
        @branchHint(.cold);
        @panic("ILLEGAL: setPipelineOperation called when pending_pipeline was not null");
    }
    self.pending_pipeline = op;

    self.updateActiveOperation();
}

pub fn setCpuOperation(self: *MemoryManager, op: Pending) void {
    if (self.pending_cpu != null) {
        @branchHint(.cold);
        @panic("ILLEGAL: setCpuOperation called when pending_cpu was not null");
    }
    self.pending_cpu = op;

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

const region = @import("./memory/region.zig");

fn resetWaitCount(self: *MemoryManager) void {
    const addr = switch (self.active_operation) {
        .idle => unreachable,
        .cpu => switch (self.pending_cpu.?) {
            .read_byte => self.pending_cpu.?.read_byte,
            .read_half => self.pending_cpu.?.read_half,
            .read_word => self.pending_cpu.?.read_word,

            .write_byte => self.pending_cpu.?.write_byte.addr,
            .write_half => self.pending_cpu.?.write_half.addr,
            .write_word => self.pending_cpu.?.write_word.addr,
        },
        .pipeline => switch (self.pending_pipeline.?) {
            // Pipeline only reads half and full words.
            .read_byte => unreachable,

            .read_half => self.pending_pipeline.?.read_half,
            .read_word => self.pending_pipeline.?.read_word,
        },
    };

    self.waits_remaining = switch (addr) {
        // ROM region is 32-bit bus, no wait state.
        region.sys_start...region.sys_end => 1,

        // Not yet implemented.
        region.ew_ram_start...region.ew_ram_end => @panic("TODO: waits for EWRAM"),
        region.iw_ram_start...region.iw_ram_end => @panic("TODO: waits for IWRAM"),
        region.io_ram_start...region.io_ram_end => @panic("TODO: waits for IO RAM"),
        region.palette_ram_start...region.palette_ram_end => @panic("TODO: waits for palette RAM"),
        region.vram_start...region.vram_end => @panic("TODO: waits for VRAM"),
        region.oam_start...region.oam_end => @panic("TODO: waits for OAM"),
        region.game_pak_start...region.game_pak_end => @panic("TODO: waits for game pak"),
    };
}

fn getRegion(self: *MemoryManager, addr: u32) MemoryRegion {
    return switch (addr) {
        region.sys_start...region.sys_end => self.regions.bios,

        else => @panic("TODO: handle more regions in getRegion"),
    };
}

fn readHalfImmediate(self: *MemoryManager, addr: u32) u16 {
    const reg = self.getRegion(addr);
    return reg.readHalf(addr).value;
}

fn readWordImmediate(self: *MemoryManager, addr: u32) u32 {
    const reg = self.getRegion(addr);
    return reg.readWord(addr).value;
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

test {
    _ = @import("./MemoryManager_test.zig");
}

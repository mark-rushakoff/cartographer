const memory = @import("./memory.zig");
const Registers = @import("./registers.zig").Registers;

pub const instructions = struct {
    pub const Thumb = @import("./instructions/thumb.zig").Thumb;
    pub const Arm = @import("./instructions/arm.zig").Arm;
};

/// The wait status of the CPU.
// TODO: there are almost certainly other states not yet accounted for.
// TODO: ready is correct to be void, but any other void is a placeholder.
pub const WaitStatus = union(enum) {
    /// Ready to execute the next instruction, if it has been fetched.
    ready: void,

    // Refer to Section 10 of the ARM7TDMI data sheet.

    pending_read_word: memory.PendingReadWord,
    pending_read_half: memory.PendingReadHalf,
    pending_read_byte: memory.PendingReadByte,

    pending_write_word: memory.PendingWriteWord,
    pending_write_half: memory.PendingWriteHalf,
    pending_write_byte: memory.PendingWriteByte,

    waiting_mul: void, // TODO: new type like InternalMul maybe?
    fetching_branch_target: void,
};

pub const Inst = union(enum) {
    arm: instructions.Arm,
    thumb: instructions.Thumb,
};

// Probably need to move the Cpu type to the arm7tdmi module,
// and then this type becomes a thin wrapper around the hardware type.
// The GBA representation of a CPU then becomes a question of
// whether a tick is delegated to the CPU or prioritized to DMA.
pub const Cpu = struct {
    status: WaitStatus,
    registers: Registers,

    pub fn init() Cpu {
        return .{
            .status = .ready,
            .registers = Registers.initial,
        };
    }

    /// While the gba module focuses on Tick as the unit for every subsystem,
    /// here the CPU steps a specific instruction at a time.
    /// That means the GBA representation of the CPU
    /// is in charge of all the operation fetching,
    /// and in charge of ensuring the WaitStatus is concluded
    /// before calling step again.
    pub fn step(self: *Cpu, inst: Inst) WaitStatus {
        _ = self;
        _ = inst;
        // Since the status is a field on Cpu,
        // it doesn't seem worth returning the value.

        // If ready: possibly wait for instruction, otherwise execute instruction.
        // If pending memory: that's the bus's issue.
        // If multiplying: count down cycles until zero.
        // If fetching branch target: not yet clear.

        return .ready;
    }
};

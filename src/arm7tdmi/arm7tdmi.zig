//! Types that are more specific to the ARM7TDMI architecture
//! than to anything particular about the Game Boy Advance.

pub const instructions = struct {
    pub const Thumb = @import("./instructions/thumb.zig").Thumb;
    pub const Arm = @import("./instructions/arm.zig").Arm;
};

pub const Registers = @import("./registers.zig").Registers;

pub const Pipeline = @import("./pipeline.zig").Pipeline;

pub const memory = @import("./memory.zig");

pub const cpu = @import("./cpu.zig");

pub const Cpu = cpu.Cpu;

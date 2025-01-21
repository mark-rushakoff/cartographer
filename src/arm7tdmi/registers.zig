/// Reference: https://mgba-emu.github.io/gbatek/#overview-11
pub const Registers = struct {
    // Registers 0-12 are usually available, depending on the mode.
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r4: u32,
    r5: u32,
    r6: u32,
    r7: u32,
    r8: u32,
    r9: u32,
    r10: u32,
    r11: u32,
    r12: u32,

    r13: u32, // SP in normal execution
    r14: u32, // LR in normal execution
    r15: u32, // PC in normal execution

    r8_fiq: u32,
    r9_fiq: u32,
    r10_fiq: u32,
    r11_fiq: u32,
    r12_fiq: u32,
    r13_fiq: u32,
    r14_fiq: u32,

    r13_svc: u32,
    r14_svc: u32,

    r13_abt: u32,
    r14_abt: u32,

    r13_irq: u32,
    r14_irq: u32,

    r13_und: u32,
    r14_und: u32,

    // Current Program Status Register.
    cpsr: u32,

    // Saved Program Status Registers, for the other modes.
    spsr_fiq: u32 = 0,
    spsr_svc: u32 = 0,
    spsr_abt: u32 = 0,
    spsr_irq: u32 = 0,
    spsr_und: u32 = 0,

    pub const initial = Registers{
        .r0 = 0,
        .r1 = 0,
        .r2 = 0,
        .r3 = 0,
        .r4 = 0,
        .r5 = 0,
        .r6 = 0,
        .r7 = 0,
        .r8 = 0,
        .r9 = 0,
        .r10 = 0,
        .r11 = 0,
        .r12 = 0,

        .r13 = 0,
        .r14 = 0,
        .r15 = 0,

        .r8_fiq = 0,
        .r9_fiq = 0,
        .r10_fiq = 0,
        .r11_fiq = 0,
        .r12_fiq = 0,
        .r13_fiq = 0,
        .r14_fiq = 0,

        .r13_svc = 0,
        .r14_svc = 0,

        .r13_abt = 0,
        .r14_abt = 0,

        .r13_irq = 0,
        .r14_irq = 0,

        .r13_und = 0,
        .r14_und = 0,

        .cpsr = 0,

        .spsr_fiq = 0,
        .spsr_svc = 0,
        .spsr_abt = 0,
        .spsr_irq = 0,
        .spsr_und = 0,
    };

    /// Report whether the sign bit is set on cpsr.
    pub fn sign(self: Registers) bool {
        return (self.cpsr & (1 << 31)) != 0;
    }

    /// Report whether the zero bit is set on cpsr.
    pub fn zero(self: Registers) bool {
        return (self.cpsr & (1 << 30)) != 0;
    }

    /// Report whether the carry bit is set on cpsr.
    pub fn carry(self: Registers) bool {
        return (self.cpsr & (1 << 29)) != 0;
    }

    /// Report whether the overflow bit is set on cpsr.
    pub fn overflow(self: Registers) bool {
        return (self.cpsr & (1 << 28)) != 0;
    }

    /// Whether the CPSR indicates ARM or THUMB execution state.
    pub const State = enum(u1) {
        arm = 0,
        thumb = 1,
    };

    // What state the CPU is in.
    pub fn state(self: Registers) State {
        return if ((self.cpsr & (1 << 5)) == 0) .arm else .thumb;
    }
};

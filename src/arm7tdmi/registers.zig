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

    // Current Program Status Register.
    cpsr: u32,

    // Saved Program Status Registers, for the other modes.
    spsr_fiq: u32 = 0,
    spsr_svc: u32 = 0,
    spsr_abt: u32 = 0,
    spsr_irq: u32 = 0,
    spsr_und: u32 = 0,

    pub const initial = Registers{
        .r0d = 0,
        .r1d = 0,
        .r2d = 0,
        .r3d = 0,
        .r4d = 0,
        .r5d = 0,
        .r6d = 0,
        .r7d = 0,
        .r8d = 0,
        .r9d = 0,
        .r10d = 0,
        .r11d = 0,
        .r12d = 0,

        .r13d = 0,
        .r14d = 0,
        .r15d = 0,

        .r8_fiqd = 0,
        .r9_fiqd = 0,
        .r10_fiqd = 0,
        .r11_fiqd = 0,
        .r12_fiqd = 0,
        .r13_fiqd = 0,
        .r14_fiqd = 0,

        .r13_svcd = 0,
        .r14_svcd = 0,

        .r13_abtd = 0,
        .r14_abtd = 0,

        .r13_irqd = 0,
        .r14_irqd = 0,

        .r13_undd = 0,
        .r14_undd = 0,

        .cpsrd = 0,

        .spsr_fiqd = 0,
        .spsr_svcd = 0,
        .spsr_abtd = 0,
        .spsr_irqd = 0,
        .spsr_undd = 0,
    };

    /// InitValues defaults every register to zero.
    /// This is the argument to `init`.
    pub const InitValues = struct {
        r0: u32 = 0,
        r1: u32 = 0,
        r2: u32 = 0,
        r3: u32 = 0,
        r4: u32 = 0,
        r5: u32 = 0,
        r6: u32 = 0,
        r7: u32 = 0,
        r8: u32 = 0,
        r9: u32 = 0,
        r10: u32 = 0,
        r11: u32 = 0,
        r12: u32 = 0,

        r13: u32 = 0,
        r14: u32 = 0,
        r15: u32 = 0,

        r8_fiq: u32 = 0,
        r9_fiq: u32 = 0,
        r10_fiq: u32 = 0,
        r11_fiq: u32 = 0,
        r12_fiq: u32 = 0,
        r13_fiq: u32 = 0,
        r14_fiq: u32 = 0,

        r13_svc: u32 = 0,
        r14_svc: u32 = 0,

        r13_abt: u32 = 0,
        r14_abt: u32 = 0,

        r13_irq: u32 = 0,
        r14_irq: u32 = 0,

        r13_und: u32 = 0,
        r14_und: u32 = 0,

        cpsr: u32 = 0,

        spsr_fiq: u32 = 0,
        spsr_svc: u32 = 0,
        spsr_abt: u32 = 0,
        spsr_irq: u32 = 0,
        spsr_und: u32 = 0,
    };

    /// Initialize a set of Registers.
    /// The InitValues argument provides a default of 0
    /// for all otherwise unspecified registers.
    pub fn init(i: InitValues) Registers {
        return .{
            .r0 = i.r0,
            .r1 = i.r1,
            .r2 = i.r2,
            .r3 = i.r3,
            .r4 = i.r4,
            .r5 = i.r5,
            .r6 = i.r6,
            .r7 = i.r7,
            .r8 = i.r8,
            .r9 = i.r9,
            .r10 = i.r10,
            .r11 = i.r11,
            .r12 = i.r12,

            .r13 = i.r13,
            .r14 = i.r14,
            .r15 = i.r15,

            // Fast interrupt bank.
            .r8_fiq = i.r8_fiq,
            .r9_fiq = i.r9_fiq,
            .r10_fiq = i.r10_fiq,
            .r11_fiq = i.r11_fiq,
            .r12_fiq = i.r12_fiq,
            .r13_fiq = i.r13_fiq,
            .r14_fiq = i.r14_fiq,

            // Supervisor bank (software interrupt).
            .r13_svc = i.r13_svc,
            .r14_svc = i.r14_svc,

            // Abort bank.
            .r13_abt = i.r13_abt,
            .r14_abt = i.r14_abt,

            // Normal interrupt request.
            .r13_irq = i.r13_irq,
            .r14_irq = i.r14_irq,

            // Undefined instruction.
            .r13_und = i.r13_und,
            .r14_und = i.r14_und,

            .cpsr = i.cpsr,

            .spsr_fiq = i.spsr_fiq,
            .spsr_svc = i.spsr_svc,
            .spsr_abt = i.spsr_abt,
            .spsr_irq = i.spsr_irq,
            .spsr_und = i.spsr_und,
        };
    }

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
        return if ((self.cpsr & 1 << 5) == 0) .arm else .thumb;
    }
};

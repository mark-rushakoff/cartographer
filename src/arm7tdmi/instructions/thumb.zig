const testing = @import("std").testing;

// Reference: ARM7TDMI Data Sheet
// (Look up ARM DDI 0029E, which appears to be labeled as "open access".)

pub const Thumb = union(enum) {
    // These values are in the same order as the data sheet.

    move_shifted: MoveShifted,
    add_subtract: AddSubtract,
    immediate: Immediate,
    alu: Alu,
    hi_register: HiRegister,
    pc_load: PcLoad,
    reg_offset: RegOffset,
    mem_sign: MemSign,
    mem_offset: MemOffset,
    mem_halfword: MemHalfword,
    access_sp: AccessSp,
    load: Load,
    adjust_sp: AdjustSp,
    stack: Stack,
    mem_multiple: MemMultiple,
    cond_branch: CondBranch,
    software_interrupt: SoftwareInterrupt,
    branch: Branch,
    long_branch: LongBranch,

    /// Format 1: move shifted register.
    ///
    /// "These instructions move a shifted value between Lo registers."
    pub const MoveShifted = struct {
        op: enum(u2) {
            lsl = 0,
            lsr = 1,
            asr = 2,
            // Undefined behavior for 3?
        },
        offset: u5,
        rs: u3,
        rd: u3,

        pub fn encode(self: MoveShifted) u16 {
            return (@as(u16, @intFromEnum(self.op)) << 11) |
                (@as(u16, self.offset) << 6) |
                (@as(u16, self.rs) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 2: add/subtract.
    ///
    /// "These instructions allow the contents of a Lo register or a 3-bit immediate value to be
    /// added to or subtracted from a Lo register."
    pub const AddSubtract = struct {
        imm: enum(u1) {
            reg = 0,
            val = 1,
        },
        op: enum(u1) {
            add = 0,
            sub = 1,
        },
        val: u3, // Register or immediate value, depending on the imm flag.
        rs: u3,
        rd: u3,

        pub fn encode(self: AddSubtract) u16 {
            return 0x1800 |
                (@as(u16, @intFromEnum(self.imm)) << 10) |
                (@as(u16, @intFromEnum(self.op)) << 9) |
                (@as(u16, self.val) << 6) |
                (@as(u16, self.rs) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 3: move/compare/add/subtract immediate.
    ///
    /// "The instructions in this group perform operations between a Lo register and an 8-bit
    /// immediate value."
    pub const Immediate = struct {
        op: enum(u2) {
            mov = 0,
            cmp = 1,
            add = 2,
            sub = 3,
        },
        rd: u3,
        val: u8,

        pub fn encode(self: Immediate) u16 {
            return 0x2000 |
                (@as(u16, @intFromEnum(self.op)) << 11) |
                (@as(u16, self.rd) << 8) |
                @as(u16, self.val);
        }
    };

    /// Format 4: ALU operations.
    ///
    /// "The following instructions perform ALU operations on a Lo register pair."
    pub const Alu = struct {
        op: enum(u4) {
            and_ = 0,
            eor = 1,
            lsl = 2,
            lsr = 3,
            asr = 4,
            adc = 5,
            sbc = 6,
            ror = 7,
            tst = 8,
            neg = 9,
            cmp = 10,
            cmn = 11,
            orr = 12,
            mul = 13,
            bic = 14,
            mvn = 15,
        },
        rs: u3,
        rd: u3,

        pub fn encode(self: Alu) u16 {
            return 0x4000 |
                (@as(u16, @intFromEnum(self.op)) << 6) |
                (@as(u16, self.rs) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 5: Hi register operations/branch exchange.
    ///
    /// "There are four sets of instructions in this group. The first three allow ADD, CMP and
    /// MOV operations to be performed between Lo and Hi registers, or a pair of Hi registers.
    /// The fourth, BX, allows a Branch to be performed which may also be used to switch
    /// processor state."
    pub const HiRegister = struct {
        op: enum(u2) {
            add = 0,
            cmp = 1,
            mov = 2,
            bx = 3,
        },
        h1: u1,
        h2: u1,
        rs: u3,
        rd: u3,

        pub fn encode(self: HiRegister) u16 {
            return 0x4400 |
                (@as(u16, @intFromEnum(self.op)) << 8) |
                (@as(u16, self.h1) << 7) |
                (@as(u16, self.h2) << 6) |
                (@as(u16, self.rs) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 6: PC-relative load.
    ///
    /// "This instruction loads a word from an address specified as a 10-bit immediate offset
    /// from the PC."
    pub const PcLoad = struct {
        rd: u3,
        val: u8,

        pub fn encode(self: PcLoad) u16 {
            return 0x4800 |
                (@as(u16, self.rd) << 8) |
                @as(u16, self.val);
        }
    };

    /// Format 7: load/store with register offset.
    ///
    /// "These instructions transfer byte or word values between registers and memory.
    /// Memory addresses are pre-indexed using an offset register in the range 0-7."
    pub const RegOffset = struct {
        l: enum(u1) {
            store = 0,
            load = 1,
        },
        b: enum(u1) {
            word = 0,
            byte = 1,
        },
        ro: u3,
        rb: u3,
        rd: u3,

        pub fn encode(self: RegOffset) u16 {
            return 0x5000 |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, @intFromEnum(self.b)) << 10) |
                (@as(u16, self.ro) << 6) |
                (@as(u16, self.rb) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 8: load/store sign-extended byte/halfword.
    ///
    /// "These instructions load optionally sign-extended bytes or halfwords,
    /// and store halfwords."
    pub const MemSign = struct {
        h: u1,
        s: u1,
        ro: u3,
        rb: u3,
        rd: u3,

        pub fn encode(self: MemSign) u16 {
            return 0x5200 |
                (@as(u16, self.h) << 11) |
                (@as(u16, self.s) << 10) |
                (@as(u16, self.ro) << 6) |
                (@as(u16, self.rb) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 9: load/store with immediate offset.
    ///
    /// "These instructions transfer byte or word values between registers
    /// and memory using an immediate 5 or 7-bit offset."
    pub const MemOffset = struct {
        b: enum(u1) {
            word = 0,
            byte = 1,
        },
        l: enum(u1) {
            store = 0,
            load = 1,
        },
        offset: u5,
        rb: u3,
        rd: u3,

        pub fn encode(self: MemOffset) u16 {
            return 0x6000 |
                (@as(u16, @intFromEnum(self.b)) << 12) |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, self.offset) << 6) |
                (@as(u16, self.rb) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 10: load/store halfword.
    ///
    /// "These instructions transfer halfword values between a Lo register and memory.
    /// Addresses are pre-indexed, using a 6-bit immediate value."
    pub const MemHalfword = struct {
        l: enum(u1) {
            store = 0,
            load = 1,
        },
        offset: u5,
        rb: u3,
        rd: u3,

        pub fn encode(self: MemHalfword) u16 {
            return 0x8000 |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, self.offset) << 6) |
                (@as(u16, self.rb) << 3) |
                @as(u16, self.rd);
        }
    };

    /// Format 11: SP-relative load/store.
    ///
    /// "The instructions in this group perform an SP-relative load or store."
    pub const AccessSp = struct {
        l: enum(u1) {
            store = 0,
            load = 1,
        },
        rd: u3,
        val: u8,

        pub fn encode(self: AccessSp) u16 {
            return 0x9000 |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, self.rd) << 8) |
                @as(u16, self.val);
        }
    };

    /// Format 12: load address.
    ///
    /// "These instructions calculate an address by adding an 10-bit constant to either the PC
    /// or the SP, and load the resulting address into a register."
    pub const Load = struct {
        src: enum(u1) {
            pc = 0,
            sp = 1,
        },
        rd: u3,
        val: u8,

        pub fn encode(self: Load) u16 {
            return 0xa000 |
                (@as(u16, @intFromEnum(self.src)) << 11) |
                (@as(u16, self.rd) << 8) |
                @as(u16, self.val);
        }
    };

    /// Format 13: add offset to Stack Pointer.
    ///
    /// "This instruction adds a 9-bit signed constant to the stack pointer."
    pub const AdjustSp = struct {
        // The datasheet has a separate sign bit and a 7-bit value
        // to be interpreted as signed or unsigned based on the sign bit.
        //
        // Seems like it makes more sense to just use an i8 here.
        offset: i8,

        pub fn encode(self: AdjustSp) u16 {
            return 0xb000 |
                @as(u16, @as(u8, @bitCast(self.offset)));
        }
    };
};

// All of the following tests are using instructions observed in the wild with a disassembler.

test "MoveShifted.encode" {
    // Logical shift left, r1, by 2, storing in r0.
    const op = Thumb.MoveShifted{
        .op = .lsl,
        .offset = 2,
        .rs = 1,
        .rd = 0,
    };

    try testing.expectEqual(0x0088, op.encode());
}

test "AddSubtract.encode" {
    // add r0, r6, r4
    // (add rd, rs, rn)
    const op = Thumb.AddSubtract{
        .imm = .reg,
        .op = .add,
        .val = 4,
        .rs = 6,
        .rd = 0,
    };

    try testing.expectEqual(0x1930, op.encode());
}

test "Immediate.encode" {
    // mov r6, #1
    const op = Thumb.Immediate{
        .op = .mov,
        .rd = 6,
        .val = 1,
    };

    try testing.expectEqual(0x2601, op.encode());
}

test "Alu.encode" {
    // cmp r6, r0
    // (cmp rd, rs)
    const op = Thumb.Alu{
        .op = .cmp,
        .rd = 6,
        .rs = 0,
    };

    try testing.expectEqual(0x4286, op.encode());
}

test "HiRegister.encode" {
    // mov r7, r10
    // (mov rd, hs)
    const op = Thumb.HiRegister{
        .op = .mov,
        .h1 = 0,
        .h2 = 1,
        .rd = 7,
        .rs = 2,
    };

    try testing.expectEqual(0x4657, op.encode());
}

test "PcLoad.encode" {
    // ldr r5, [pc, #0xb0]
    // (ldr rd, [pc, #imm])
    const op = Thumb.PcLoad{
        .rd = 5,

        // "the assembler places #Imm >> 2 in field [val]"
        .val = 0xb0 >> 2,
    };

    try testing.expectEqual(0x4d2c, op.encode());
}

test "RegOffset.encode" {
    // str r3, [r2, r6]
    // (str rd, [rb, ro]
    const op = Thumb.RegOffset{
        .l = .store,
        .b = .word,
        .ro = 6,
        .rb = 2,
        .rd = 3,
    };

    try testing.expectEqual(0x5193, op.encode());
}

test "MemSign.encode" {
    // ldsb r0, [r5, r1]
    // (ldsb rd, [rb, ro]
    const op = Thumb.MemSign{
        .h = 0,
        .s = 1,
        .ro = 1,
        .rb = 5,
        .rd = 0,
    };

    try testing.expectEqual(0x5668, op.encode());
}

test "MemOffset.encode" {
    // str r1, [r0, #0xc]
    // (str rd, [rb, #imm])
    const op = Thumb.MemOffset{
        .b = .word,
        .l = .store,

        // "the assembler places #Imm >> 2 in the [offset] field"
        .offset = 0xc >> 2,
        .rb = 0,
        .rd = 1,
    };

    try testing.expectEqual(0x60c1, op.encode());
}

test "MemHalfword.encode" {
    // ldrh r1, [r4, #6]
    // (ldrh rd, [rb, #imm])
    const op = Thumb.MemHalfword{
        .l = .load,

        // "the assembler places #Imm >> 2 in the [offset] field"
        .offset = 6 >> 1,
        .rb = 4,
        .rd = 1,
    };

    try testing.expectEqual(0x88e1, op.encode());
}

test "AccessSp.encode" {
    // str r1, [sp, #8]
    // (str rd, [sp, #imm])
    const op = Thumb.AccessSp{
        .l = .store,
        .rd = 1,

        // "the assembler places #Imm >> 2 in the [offset] field"
        .val = 8 >> 2,
    };

    try testing.expectEqual(0x9102, op.encode());
}

test "Load.encode" {
    // add r5, sp, #0xc
    // (add rd, sp, #imm)
    const op = Thumb.Load{
        .src = .sp,
        .rd = 5,

        // "the assembler places #Imm >> 2 in field [val]"
        .val = 0xc >> 2,
    };

    try testing.expectEqual(0xad03, op.encode());
}

test "AdjustSp.encode" {
    // add sp, #0x18
    // (add sp, #imm)
    const op_add = Thumb.AdjustSp{
        .offset = 0x18 >> 2,
    };

    try testing.expectEqual(0xb006, op_add.encode());

    // sub sp, #0x18
    // (sub sp, #-imm)
    const op_sub = Thumb.AdjustSp{
        .offset = -(0x18 >> 2),
    };

    try testing.expectEqual(0xb086, op_sub.encode());
}

/// Format 14: push/pop registers.
///
/// "The instructions in this group allow registers 0-7
/// and optionally LR to be pushed onto the stack,
/// and registers 0-7 and optionally PC to be popped off the stack."
pub const Stack = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    r: enum(u1) {
        no_store = 0,
        store = 1,
    },
    rlist: u8,
};

/// Format 15: multiple load/store.
///
/// "These instructions allow multiple loading and storing of Lo registers."
pub const MemMultiple = struct {
    l: enum(u1) {
        store = 0,
        load = 1,
    },
    rb: u3,
    rlist: u8,
};

/// Format 16: conditional branch.
///
/// "The instructions in this group all perform a conditional Branch
/// depending on the state of the CPSR condition codes."
pub const CondBranch = struct {
    cond: enum(u4) {
        eq = 0,
        ne = 1,
        cs = 2,
        cc = 3,
        mi = 4,
        pl = 5,
        vs = 6,
        vc = 7,
        hi = 8,
        ls = 9,
        ge = 10,
        lt = 11,
        gt = 12,
        le = 13,
    },
    offset: i8,
};

/// Format 17: software interrupt.
///
/// "The SWI instruction performs a software interrupt."
pub const SoftwareInterrupt = struct {
    val: u8,
};

/// Format 18: unconditional branch.
///
/// "This instruction performs a PC-relative Branch."
pub const Branch = struct {
    offset: i11,
};

/// Format 19: long branch with link.
///
/// "This format specifies a long branch with link."
pub const LongBranch = struct {
    h: enum(u1) {
        high = 0,
        low = 1,
    },
    offset: i11,
};

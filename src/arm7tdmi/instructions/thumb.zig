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
            and_ = 0b0000,
            eor = 0b0001,
            lsl = 0b0010,
            lsr = 0b0011,
            asr = 0b0100,
            adc = 0b0101,
            sbc = 0b0110,
            ror = 0b0111,
            tst = 0b1000,
            neg = 0b1001,
            cmp = 0b1010,
            cmn = 0b1011,
            orr = 0b1100,
            mul = 0b1101,
            bic = 0b1110,
            mvn = 0b1111,
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
    /// ...
    /// "The offset specified by #Imm can be up to -/+ 508, but must be word-aligned (ie with
    /// bits 1:0 set to 0) since the assembler converts #Imm to an 8-bit sign + magnitude
    /// number before placing it in field SWord7."
    ///
    /// In other words, the value written in assembly is divided by 4 when encoded.
    pub const AdjustSp = struct {
        op: enum(u1) {
            add = 0,
            sub = 1,
        },
        offset: u7,

        pub fn encode(self: AdjustSp) u16 {
            return 0xb000 |
                (@as(u16, @intFromEnum(self.op)) << 7) |
                @as(u16, @as(u7, @bitCast(self.offset)));
        }
    };

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

        pub fn encode(self: Stack) u16 {
            return 0xb400 |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, @intFromEnum(self.r)) << 8) |
                self.rlist;
        }
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

        pub fn encode(self: MemMultiple) u16 {
            return 0xc000 |
                (@as(u16, @intFromEnum(self.l)) << 11) |
                (@as(u16, self.rb) << 8) |
                self.rlist;
        }
    };

    /// Format 16: conditional branch.
    ///
    /// "The instructions in this group all perform a conditional Branch
    /// depending on the state of the CPSR condition codes."
    pub const CondBranch = struct {
        cond: enum(u4) {
            eq = 0b0000,
            ne = 0b0001,
            cs = 0b0010,
            cc = 0b0011,
            mi = 0b0100,
            pl = 0b0101,
            vs = 0b0110,
            vc = 0b0111,
            hi = 0b1000,
            ls = 0b1001,
            ge = 0b1010,
            lt = 0b1011,
            gt = 0b1100,
            le = 0b1101,

            // Code 14 is "undefined, and should not be used",
            // while code 15 indicates SWI.
        },

        // "The branch offset must take account of the prefetch operation,
        // which causes the PCto be 1 word (4 bytes) ahead of the current instruction."
        //
        // "While label specifies a full 9-bit two’s complement address, this must always be
        // halfword-aligned (ie with bit 0 set to 0) since the assembler actually places label >> 1
        // in field SOffset8."
        offset: i8,

        pub fn encode(self: CondBranch) u16 {
            return 0xd000 |
                (@as(u16, @intFromEnum(self.cond)) << 8) |
                (@as(u16, @as(u8, @bitCast(self.offset))));
        }
    };

    /// Format 17: software interrupt.
    ///
    /// "The SWI instruction performs a software interrupt."
    pub const SoftwareInterrupt = struct {
        val: u8,

        pub fn encode(self: SoftwareInterrupt) u16 {
            return 0xdf00 |
                @as(u16, self.val);
        }
    };

    /// Format 18: unconditional branch.
    ///
    /// "This instruction performs a PC-relative Branch."
    pub const Branch = struct {
        // "The branch offset must take account of the prefetch operation, which
        // causes the PC to be 1 word (4 bytes) ahead of the current instruction."
        //
        // "The address specified by label is a full 12-bit two’s complement address, but must
        // always be halfword aligned (ie bit 0 set to 0), since the assembler places label >> 1 in
        // the Offset11 field."
        offset: i11,

        pub fn encode(self: Branch) u16 {
            return 0xe000 |
                @as(u16, @as(u11, @bitCast(self.offset)));
        }
    };

    /// Format 19: long branch with link.
    ///
    /// "This format specifies a long branch with link."
    pub const LongBranch = struct {
        h: enum(u1) {
            high = 0,
            low = 1,
        },

        // The final offset in assembly ends up as a 23-bit integer,
        // the least significant bit of which is 0,
        // which is how it is encoded as 22-bits.
        // Since we have to split it into two segments of 11 bits,
        // we represent it as unsigned prior to reassemblign the full offset.
        offset: u11,

        pub fn encode(self: LongBranch) u16 {
            return 0xf000 |
                (@as(u16, @intFromEnum(self.h)) << 11) |
                @as(u16, self.offset);
        }
    };

    pub fn decode(op: u16) Thumb {
        if (op == 8315) {
            return .{
                .immediate = .{
                    .op = .mov,
                    .rd = 0,
                    .val = 123,
                },
            };
        }

        @panic("TODO: decode op != 8315 (temporary placeholder for pipeline test)");
    }
};

const testing = @import("std").testing;

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
        .op = .add,
        .offset = 0x18 >> 2,
    };

    try testing.expectEqual(0xb006, op_add.encode());

    // sub sp, #0x18
    // (sub sp, #imm)
    const op_sub = Thumb.AdjustSp{
        .op = .sub,
        .offset = 0x18 >> 2,
    };

    try testing.expectEqual(0xb086, op_sub.encode());
}

test "Stack.encode" {
    // pop {r4, r5, r6, r7}
    // (pop {rlist})
    const op_pop = Thumb.Stack{
        .l = .load,
        .r = .no_store,
        .rlist = (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7),
    };

    try testing.expectEqual(0xbcf0, op_pop.encode());

    // push {r4, lr}
    // (push {rlist, lr})
    const op_push_lr = Thumb.Stack{
        .l = .store,
        .r = .store,
        .rlist = (1 << 4),
    };

    try testing.expectEqual(0xb510, op_push_lr.encode());
}

test "MemMultiple.encode" {
    // stmia r0!, {r3-r7}
    // stmia rb!, {rlist}
    const op = Thumb.MemMultiple{
        .l = .store,
        .rb = 0,
        .rlist = (1 << 3) | (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7),
    };
    try testing.expectEqual(0xc0f8, op.encode());
}

test "CondBranch.encode" {
    // "The branch offset must take account of the prefetch operation,
    // which causes the PCto be 1 word (4 bytes) ahead of the current instruction."

    // bhi +0x20
    const op_forward = Thumb.CondBranch{
        .cond = .hi,
        .offset = (0x20 - 4) >> 1,
    };
    try testing.expectEqual(0xd80e, op_forward.encode());

    // bge -0x16
    const op_backward = Thumb.CondBranch{
        .cond = .ge,
        .offset = (-0x16 - 4) >> 1,
    };
    try testing.expectEqual(0xdaf3, op_backward.encode());
}

test "SoftwareInterrupt.encode" {
    // swi 0xab
    const op = Thumb.SoftwareInterrupt{
        .val = 0xab,
    };
    try testing.expectEqual(0xdfab, op.encode());
}

test "Branch.encode" {
    // b +0xac
    const op_forward = Thumb.Branch{
        .offset = (0xac - 4) >> 1,
    };
    try testing.expectEqual(0xe054, op_forward.encode());

    // b -0x122
    const op_backward = Thumb.Branch{
        .offset = (-0x122 - 4) >> 1,
    };
    try testing.expectEqual(0xe76d, op_backward.encode());
}

test "LongBranch.encode" {
    // Upper bits first
    const op_upper = Thumb.LongBranch{
        .h = .high,
        .offset = 0x7ca,
    };
    try testing.expectEqual(0xf7ca, op_upper.encode());

    const op_lower = Thumb.LongBranch{
        .h = .low,
        .offset = 0xa3,
    };
    try testing.expectEqual(0xf8a3, op_lower.encode());
}

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

    // Illegal opcodes.
    undef: Undefined,

    /// Format 1: move shifted register.
    ///
    /// "These instructions move a shifted value between Lo registers."
    pub const MoveShifted = struct {
        op: enum(u2) {
            lsl = 0,
            lsr = 1,
            asr = 2,
            // 3 indicates the AddSubtract instruction.
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

        fn decode(op: u16) Thumb {
            return .{
                .move_shifted = .{
                    .op = @enumFromInt((op >> 11) & 3),
                    .offset = @truncate((op >> 6) & 0x1f),
                    .rs = @truncate((op >> 3) & 3),
                    .rd = @truncate(op & 3),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .add_subtract = .{
                    .imm = @enumFromInt((op >> 10) & 1),
                    .op = @enumFromInt((op >> 9) & 1),
                    .val = @truncate((op >> 6) & 7),
                    .rs = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .immediate = .{
                    .op = @enumFromInt((op >> 11) & 3),
                    .rd = @truncate((op >> 8) & 7),
                    .val = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .alu = .{
                    .op = @enumFromInt((op >> 6) & 0xf),
                    .rs = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .hi_register = .{
                    .op = @enumFromInt((op >> 8) & 3),
                    .h1 = @truncate((op >> 7) & 1),
                    .h2 = @truncate((op >> 6) & 1),
                    .rs = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .pc_load = .{
                    .rd = @truncate((op >> 8) & 7),
                    .val = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .reg_offset = .{
                    .l = @enumFromInt((op >> 11) & 1),
                    .b = @enumFromInt((op >> 10) & 1),
                    .ro = @truncate((op >> 6) & 7),
                    .rb = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .mem_sign = .{
                    .h = @truncate((op >> 11) & 1),
                    .s = @truncate((op >> 10) & 1),
                    .ro = @truncate((op >> 6) & 7),
                    .rb = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .mem_offset = .{
                    .b = @enumFromInt((op >> 12) & 1),
                    .l = @enumFromInt((op >> 11) & 1),
                    .offset = @truncate((op >> 6) & 0x1f),
                    .rb = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .mem_halfword = .{
                    .l = @enumFromInt((op >> 11) & 1),
                    .offset = @truncate((op >> 6) & 0x1f),
                    .rb = @truncate((op >> 3) & 7),
                    .rd = @truncate(op & 7),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .access_sp = .{
                    .l = @enumFromInt((op >> 11) & 1),
                    .rd = @truncate((op >> 8) & 7),
                    .val = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .load = .{
                    .src = @enumFromInt((op >> 11) & 1),
                    .rd = @truncate((op >> 8) & 7),
                    .val = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .adjust_sp = .{
                    .op = @enumFromInt((op >> 7) & 1),
                    .offset = @truncate(op & 0x7f),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .stack = .{
                    .l = @enumFromInt((op >> 11) & 1),
                    .r = @enumFromInt((op >> 8) & 1),
                    .rlist = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .mem_multiple = .{
                    .l = @enumFromInt((op >> 11) & 1),
                    .rb = @truncate((op >> 8) & 7),
                    .rlist = @truncate(op & 0xff),
                },
            };
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
            // and we return an Undefined instruction for that during decode.
            // Code 15 indicates SWI.
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

        fn decode(op: u16) Thumb {
            const cond: u4 = @truncate((op >> 8) & 0xf);
            if (cond == 14) {
                // Undefined per the cond enum.
                return .{
                    .undef = .{ .op = op },
                };
            }

            return .{
                .cond_branch = .{
                    .cond = @enumFromInt(cond),
                    .offset = @as(i8, @bitCast(@as(u8, @truncate(op & 0xff)))),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .software_interrupt = .{
                    .val = @truncate(op & 0xff),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .branch = .{
                    .offset = @as(i11, @bitCast(@as(u11, @truncate(op & 0x7ff)))),
                },
            };
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

        fn decode(op: u16) Thumb {
            return .{
                .long_branch = .{
                    .h = @enumFromInt((op >> 11) & 1),
                    .offset = @truncate(op & 0x7ff),
                },
            };
        }
    };

    pub const Undefined = struct {
        op: u32,
    };

    pub fn decode(op: u16) Thumb {
        switch (op) {
            0x0000...0x17ff => return Thumb.MoveShifted.decode(op),
            0x1800...0x1fff => return Thumb.AddSubtract.decode(op),
            0x2000...0x3fff => return Thumb.Immediate.decode(op),
            0x4000...0x43ff => return Thumb.Alu.decode(op),
            0x4400...0x47ff => return Thumb.HiRegister.decode(op),
            0x4800...0x4fff => return Thumb.PcLoad.decode(op),

            // A weird pairing with a toggled bit in the middle.
            0x5000...0x5fff => return decodeRegOffsetOrMemSign(op),

            0x6000...0x7fff => return Thumb.MemOffset.decode(op),
            0x8000...0x8fff => return Thumb.MemHalfword.decode(op),
            0x9000...0x9fff => return Thumb.AccessSp.decode(op),
            0xa000...0xafff => return Thumb.Load.decode(op),
            0xb000...0xb0ff => return Thumb.AdjustSp.decode(op),

            // Stack is weird due to a fixed bits at 9 and 10 but variable bit at 11.
            0xb100...0xbfff => return decodeStackOrUndefined(op),

            0xc000...0xcfff => return Thumb.MemMultiple.decode(op),
            0xd000...0xdeff => return Thumb.CondBranch.decode(op),
            0xdf00...0xdfff => return Thumb.SoftwareInterrupt.decode(op),
            0xe000...0xe7ff => return Thumb.Branch.decode(op),

            // This section is absent from the THUMB instruction set
            // portion of the data sheet.
            0xe800...0xefff => return .{
                .undef = .{ .op = op },
            },

            0xf000...0xffff => return Thumb.LongBranch.decode(op),
        }
    }

    fn decodeRegOffsetOrMemSign(op: u16) Thumb {
        if ((op & (1 << 9)) == 0) {
            return RegOffset.decode(op);
        }

        return MemSign.decode(op);
    }

    fn decodeStackOrUndefined(op: u16) Thumb {
        if (((op >> 9) & 3) != 0b10) {
            return .{
                .undef = .{ .op = op },
            };
        }

        return Stack.decode(op);
    }
};

test {
    _ = @import("./thumb_test.zig");
}

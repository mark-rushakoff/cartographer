pub const Arm = union(enum) {
    branch_exchange: BranchExchange,
    branch_link: BranchLink,
    data_process: DataProcess,
    mrs: Mrs,
    msr: Msr,
    msr_flags: MsrFlags,
    mul: Multiply,
    mull: MultiplyLong,
    single_data_transfer: SingleDataTransfer,
    half_data_transfer: HalfDataTransfer,
    block_data_transfer: BlockDataTransfer,
    swap: Swap,

    /// The condition field, part of every(?) ARM instruction.
    ///
    /// Section 4.2.
    pub const Cond = enum(u4) {
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
        al = 0b1110,
        reserved = 0b1111,

        /// Returns a u32 with the 4 most significant bits set to
        /// the underlying bits of the Cond.
        pub fn bits(self: Cond) u32 {
            return @as(u32, @intFromEnum(self)) << 28;
        }

        /// Get the Cond value from the given u32 ARM opcode.
        pub fn fromOpcode(op: u32) Cond {
            const i: u4 = @truncate(op >> 28);
            return @enumFromInt(i);
        }
    };

    /// Branch and Exchange (BX).
    ///
    /// "This instruction performs a branch by copying the contents of a general register,
    /// Rn, into the program counter, PC."
    ///
    /// Section 4.3.
    pub const BranchExchange = struct {
        cond: Cond,
        rn: u4,

        pub fn encode(self: BranchExchange) u32 {
            return self.cond.bits() |
                fixed_bits |
                @as(u32, self.rn);
        }

        pub fn decode(op: u32) BranchExchange {
            return .{
                .cond = Cond.fromOpcode(op),
                .rn = @truncate(op & 0xf),
            };
        }

        const const_mask = 0x3ff_fff0;
        const fixed_bits = 0x12f_ff10;
    };

    /// Branch and Branch with Link (B, BL).
    ///
    /// "Branch instructions contain a signed 2's complement 24 bit offset.
    /// This is shifted left two bits, sign extended to 32 bits, and added to the PC...
    /// The branch offset must take account of the prefetch operation,
    /// which causes the PC to be 2 words (8 bytes) ahead of the current instruction."
    ///
    /// Section 4.4.
    pub const BranchLink = struct {
        cond: Cond,
        l: enum(u1) {
            branch = 0,
            link = 1,
        },
        offset: i24,

        pub fn encode(self: BranchLink) u32 {
            return self.cond.bits() |
                0x0a00_0000 |
                @as(u32, @intFromEnum(self.l)) << 24 |
                @as(u32, @as(u24, @bitCast(self.offset)));
        }

        pub fn decode(op: u32) BranchLink {
            return .{
                .cond = Cond.fromOpcode(op),
                .l = @enumFromInt((op >> 24) & 1),
                .offset = @bitCast(
                    @as(u24, @truncate(op)),
                ),
            };
        }
    };

    /// Data Processing.
    ///
    /// "The instruction produces a result by performing a specified arithmetic or logical
    /// operation on one or two operands."
    ///
    /// Section 4.5.
    pub const DataProcess = struct {
        cond: Cond,
        // This struct diverges slightly from most others,
        // because instead of separating the i bit
        // (which indicates whether the operation is on a register or immediate value)
        // we merge that bit into the tagged union of the op field.
        opcode: OpCode,

        // Whether to set condition codes.
        // Note, there are some special cases of opcode when s=0
        // that are different instructions (MRS and MSR to be exact).
        s: u1,
        rn: u4,
        rd: u4,
        op: Operand,

        pub const OpCode = enum(u4) {
            and_ = 0b0000,
            eor = 0b0001,
            sub = 0b0010,
            rsb = 0b0011,
            add = 0b0100,
            adc = 0b0101,
            sbc = 0b0110,
            rsc = 0b0111,
            tst = 0b1000,
            teq = 0b1001,
            cmp = 0b1010,
            cmn = 0b1011,
            orr = 0b1100,
            mov = 0b1101,
            bic = 0b1110,
            mvn = 0b1111,
        };

        pub const Operand = union(enum) {
            register: struct {
                shift: u8,
                rm: u4,

                pub fn bits(self: @This()) u12 {
                    return @as(u12, self.shift) << 4 |
                        @as(u12, self.rm);
                }
            },
            value: struct {
                rot: u4,
                imm: u8,

                pub fn bits(self: @This()) u12 {
                    return @as(u12, self.rot) << 8 |
                        @as(u12, self.imm);
                }
            },

            pub fn bits(self: @This()) u32 {
                return switch (self) {
                    .register => @as(u32, self.register.bits()),
                    .value => 1 << 25 | @as(u32, self.value.bits()),
                };
            }

            pub fn decode(op: u32) @This() {
                if ((op & (1 << 25)) > 0) {
                    return .{
                        .value = .{
                            .rot = @truncate((op >> 8) & 0xf),
                            .imm = @truncate(op & 0xff),
                        },
                    };
                }

                return .{
                    .register = .{
                        .shift = @truncate((op >> 4) & 0xff),
                        .rm = @truncate(op & 0xf),
                    },
                };
            }
        };

        pub fn encode(self: DataProcess) u32 {
            return self.cond.bits() |
                // Bits 26 and 27 are hardcoded to zero,
                // so we have no literal value included here like the other opcodes.
                // And Bit 25 would be the i bit, but that ends up being part of self.op.bits.
                @as(u32, @intFromEnum(self.opcode)) << 21 |
                @as(u32, self.s) << 20 |
                @as(u32, self.rn) << 16 |
                @as(u32, self.rd) << 12 |
                self.op.bits();
        }

        pub fn decode(op: u32) DataProcess {
            return .{
                .cond = Cond.fromOpcode(op),
                .opcode = @enumFromInt((op >> 21) & 0xf),
                .s = @truncate((op >> 20) & 1),
                .rn = @truncate((op >> 16) & 0xf),
                .rd = @truncate((op >> 12) & 0xf),
                .op = Operand.decode(op),

                // Example from some random thumb instruction:
                // .op = @enumFromInt((op >> 11) & 3),
                // .offset = @truncate((op >> 6) & 0x1f),
                // .rs = @truncate((op >> 3) & 3),
                // .rd = @truncate(op & 3),
            };
        }
    };

    /// PSR Transfer: MRS.
    ///
    /// "The MRS instruction allows the contents of the CPSR or SPSR_<mode>
    /// to be moved to a general register."
    ///
    /// Section 4.6.
    pub const Mrs = struct {
        cond: Cond,
        src: op_bits.Psr(22),
        rd: u4,

        pub fn encode(self: Mrs) u32 {
            return self.cond.bits() |
                1 << 24 |
                self.src.bits() |
                0xf << 16 |
                @as(u32, self.rd) << 12;
        }

        pub fn decode(op: u32) Mrs {
            return .{
                .cond = Cond.fromOpcode(op),
                .src = @enumFromInt((op >> 22) & 1),
                .rd = @truncate(op >> 12),
            };
        }
    };

    /// PSR Transfer: MSR.
    ///
    /// "The MSR instruction allows the contents of a general register to be
    /// moved to the CPSR or SPSR_<mode> register."
    ///
    /// The MSR instruction also allows an immediate value or register contents to be
    /// transferred to the condition code flags (N,Z,C and V) of CPSR or SPSR_<mode>
    /// without affecting the control bits.
    ///
    /// Section 4.6.
    pub const Msr = struct {
        cond: Cond,
        dst: op_bits.Psr(22),
        rm: u4,

        pub fn encode(self: Msr) u32 {
            return self.cond.bits() |
                1 << 24 |
                self.dst.bits() |
                0x29f << 12 |
                @as(u32, self.rm);
        }

        pub fn decode(op: u32) Msr {
            return .{
                .cond = Cond.fromOpcode(op),
                .dst = @enumFromInt((op >> 22) & 1),
                .rm = @truncate(op),
            };
        }
    };

    /// PSR Transfer: MSR (flags only).
    ///
    /// "The MSR instruction also allows an immediate value or register contents to be
    /// transferred to the condition code flags (N,Z,C and V) of CPSR or SPSR_<mode>
    /// without affecting the control bits."
    ///
    /// Section 4.6.
    pub const MsrFlags = struct {
        cond: Cond,
        // i bit is implied through operand enum.
        dst: op_bits.Psr(22),
        op: Operand,

        pub const Operand = union(enum) {
            register: struct {
                rm: u4,

                fn bits(self: @This()) u12 {
                    return self.rm;
                }
            },
            immediate: struct { // TODO: should this be value to match DataProcess.value?
                rot: u4,
                imm: u8,

                fn bits(self: @This()) u12 {
                    return @as(u12, self.rot) << 8 |
                        self.imm;
                }
            },

            fn bits(self: @This()) u32 {
                return switch (self) {
                    .register => @as(u32, self.register.bits()),
                    .immediate => 1 << 25 | @as(u32, self.immediate.bits()),
                };
            }

            fn decode(op: u32) @This() {
                if ((op & (1 << 25)) == 0) {
                    return .{
                        .register = .{
                            .rm = @truncate(op & 0xf),
                        },
                    };
                }

                return .{
                    .immediate = .{
                        .rot = @truncate((op >> 8) & 0xf),
                        .imm = @truncate(op & 0xff),
                    },
                };
            }
        };

        pub fn encode(self: MsrFlags) u32 {
            return self.cond.bits() |
                0x128f << 12 |
                self.dst.bits() |
                self.op.bits();
        }

        pub fn decode(op: u32) MsrFlags {
            return .{
                .cond = Cond.fromOpcode(op),
                .dst = @enumFromInt((op >> 22) & 1),
                .op = Operand.decode(op),
            };
        }
    };

    /// Multiply and Multiply-Accumulate.
    ///
    /// "The multiply form of the instruction gives Rd:=Rm*Rs. Rn is ignored, and should be
    /// set to zero for compatibility with possible future upgrades to the instruction set.
    ///
    /// "The multiply-accumulate form gives Rd:=Rm*Rs+Rn, which can save an explicit ADD
    /// instruction in some circumstances."
    ///
    /// Section 4.7.
    pub const Multiply = struct {
        cond: Cond,
        /// Whether to accumulate with the multiply.
        a: u1,

        /// Whether to set the condition codes with the multiply.
        s: u1,

        rd: u4,
        rn: u4,
        rs: u4,
        rm: u4,

        pub fn encode(self: Multiply) u32 {
            return fixed_bits |
                self.cond.bits() |
                @as(u32, self.a) << 21 |
                @as(u32, self.s) << 20 |
                @as(u32, self.rd) << 16 |
                @as(u32, self.rn) << 12 |
                @as(u32, self.rs) << 8 |
                self.rm;
        }

        pub fn decode(op: u32) Multiply {
            return .{
                .cond = Cond.fromOpcode(op),
                .a = @truncate((op >> 21) & 1),
                .s = @truncate((op >> 20) & 1),

                .rd = @truncate((op >> 16) & 0xf),
                .rn = @truncate((op >> 12) & 0xf),
                .rs = @truncate((op >> 8) & 0xf),
                .rm = @truncate(op & 0xf),
            };
        }

        const const_mask = 0xfc0_00f0;
        const fixed_bits = 0x90;
    };

    /// Multiply Long and Multiply-Accumulate Long.
    ///
    /// "The multiply long instructions perform integer multiplication on two 32 bit operands
    /// and produce 64 bit results."
    /// Section 4.8.
    pub const MultiplyLong = struct {
        cond: Cond,
        sign: enum(u1) {
            unsigned = 0,
            signed = 1,

            fn bits(self: @This()) u32 {
                return switch (self) {
                    .unsigned => 0,
                    .signed => 1 << 22,
                };
            }
        },

        /// Whether to accumulate with the multiply.
        a: u1,

        /// Whether to set the condition codes with the multiply.
        s: u1,

        rd_hi: u4,
        rd_lo: u4,
        rs: u4,
        rm: u4,

        pub fn encode(self: MultiplyLong) u32 {
            return fixed_bits |
                self.cond.bits() |
                self.sign.bits() |
                @as(u32, self.a) << 21 |
                @as(u32, self.s) << 20 |
                @as(u32, self.rd_hi) << 16 |
                @as(u32, self.rd_lo) << 12 |
                @as(u32, self.rs) << 8 |
                self.rm;
        }

        pub fn decode(op: u32) MultiplyLong {
            return .{
                .cond = Cond.fromOpcode(op),
                .sign = @enumFromInt((op >> 22) & 1),

                .a = @truncate((op >> 21) & 1),
                .s = @truncate((op >> 20) & 1),

                .rd_hi = @truncate((op >> 16) & 0xf),
                .rd_lo = @truncate((op >> 12) & 0xf),
                .rs = @truncate((op >> 8) & 0xf),
                .rm = @truncate(op & 0xf),
            };
        }

        const const_mask = 0xf80_00f0;
        const fixed_bits = 0x080_0090;
    };

    /// Single Data Transfer.
    ///
    /// "The single data transfer instructions are used to load or store single bytes or words of data."
    ///
    /// Section 4.9.
    pub const SingleDataTransfer = struct {
        cond: Cond,
        // i value implied through offset union.

        p: op_bits.PrePostIndexing(24),

        u: op_bits.UpDown(23),

        b: op_bits.ByteWord,

        w: u1,

        l: op_bits.LoadStore(20),

        rn: u4,
        rd: u4,

        offset: Offset,

        pub const Offset = union(enum) {
            imm: u12,
            reg: struct {
                shift: u8,
                rm: u4,
            },

            fn bits(self: @This()) u32 {
                return switch (self) {
                    .imm => self.imm,
                    .reg => 1 << 25 |
                        @as(u32, self.reg.shift) << 4 |
                        self.reg.rm,
                };
            }

            fn decode(op: u32) @This() {
                if ((op & (1 << 25)) > 0) {
                    return .{
                        .reg = .{
                            .shift = @truncate((op >> 4) & 0xff),
                            .rm = @truncate(op & 0xf),
                        },
                    };
                }

                return .{
                    .imm = @truncate(op & 0xfff),
                };
            }
        };

        pub fn encode(self: SingleDataTransfer) u32 {
            return self.cond.bits() |
                1 << 26 | // Constant bit.
                // Skip i, that is part of offset.bits.
                @as(u32, @intFromEnum(self.p)) << 24 |
                @as(u32, @intFromEnum(self.u)) << 23 |
                @as(u32, @intFromEnum(self.b)) << 22 |
                @as(u32, self.w) << 21 |
                @as(u32, @intFromEnum(self.l)) << 20 |
                @as(u32, self.rn) << 16 |
                @as(u32, self.rd) << 12 |
                self.offset.bits();
        }

        pub fn decode(op: u32) SingleDataTransfer {
            return .{
                .cond = Cond.fromOpcode(op),
                .p = @enumFromInt((op >> 24) & 1),
                .u = @enumFromInt((op >> 23) & 1),
                .b = @enumFromInt((op >> 22) & 1),
                .w = @truncate((op >> 21) & 1),
                .l = @enumFromInt((op >> 20) & 1),
                .rn = @truncate((op >> 16) & 0xf),
                .rd = @truncate((op >> 8) & 0xf),
                .offset = Offset.decode(op),
            };
        }
    };

    /// Halfword and Signed Data Transfer.
    ///
    /// "These instructions are used to load or store half-words of data and also load
    /// sign-extended bytes or half-words of data."
    ///
    /// Section 4.10.
    pub const HalfDataTransfer = struct {
        cond: Cond,

        p: op_bits.PrePostIndexing(24),

        u: op_bits.UpDown(23),

        w: u1,

        l: op_bits.LoadStore(20),

        rn: u4,
        rd: u4,

        sh: enum(u2) {
            // swp would be zero,
            // but that is a separate instruction.
            // Avoiding an enum value for zero
            // should help ensure we don't have any paths within HalfDataTransfer
            // that assume swp.

            u_half = 0b01,
            s_byte = 0b10,
            s_half = 0b11,
        },

        offset: Offset,

        pub const Offset = union(enum) {
            rm: u4,
            imm: u8,

            pub fn bits(self: @This()) u32 {
                return switch (self) {
                    .rm => self.rm,
                    .imm => @as(u32, 1 << 22) |
                        ((self.imm & 0xf0) << 4) |
                        (self.imm & 0xf),
                };
            }

            fn decode(op: u32) @This() {
                if ((op & (1 << 22)) > 0) {
                    return .{
                        .imm = @as(u8, @truncate((op & 0xf00) >> 4)) |
                            @as(u8, @truncate(op & 0xf)),
                    };
                }

                return .{
                    .rm = @truncate(op & 0xf),
                };
            }
        };

        pub fn encode(self: HalfDataTransfer) u32 {
            return self.cond.bits() |
                self.p.bits() |
                self.u.bits() |
                @as(u32, self.w) << 21 |
                self.l.bits() |
                @as(u32, self.rn) << 16 |
                @as(u32, self.rd) << 12 |
                9 << 4 | // Constant bits.
                @as(u32, @intFromEnum(self.sh)) << 5 |
                self.offset.bits();
        }

        pub fn decode(op: u32) HalfDataTransfer {
            return .{
                .cond = Cond.fromOpcode(op),
                .p = @enumFromInt((op >> 24) & 1),
                .u = @enumFromInt((op >> 23) & 1),
                .w = @truncate((op >> 21) & 1),
                .l = @enumFromInt((op >> 20) & 1),
                .rn = @truncate((op >> 16) & 0xf),
                .rd = @truncate((op >> 12) & 0xf),

                .sh = @enumFromInt((op >> 5) & 3),

                .offset = Offset.decode(op),
            };
        }

        const const_mask = 0xe00_0090;
        const fixed_bits = 0x90;
    };

    /// Block Data Transfer.
    ///
    /// "Block data transfer instructions are used to load (LDM) or store (STM) any subset of
    /// the currently visible registers."
    ///
    /// Section 4.11.
    pub const BlockDataTransfer = struct {
        cond: Cond,

        p: op_bits.PrePostIndexing(24),
        u: op_bits.UpDown(23),
        s: u1, // TODO?
        w: u1, // TODO?
        l: op_bits.LoadStore(20),

        rn: u4,
        rlist: u16,

        pub fn encode(self: BlockDataTransfer) u32 {
            return fixed_bits |
                self.cond.bits() |
                self.p.bits() |
                self.u.bits() |
                @as(u32, self.s) << 22 |
                @as(u32, self.w) << 21 |
                self.l.bits() |
                @as(u32, self.rn) << 16 |
                self.rlist;
        }

        pub fn decode(op: u32) BlockDataTransfer {
            return .{
                .cond = Cond.fromOpcode(op),
                .p = @enumFromInt((op >> 24) & 1),
                .u = @enumFromInt((op >> 23) & 1),
                .s = @truncate((op >> 22) & 1),
                .w = @truncate((op >> 21) & 1),
                .l = @enumFromInt((op >> 20) & 1),
                .rn = @truncate((op >> 16) & 0xf),
                .rlist = @truncate(op & 0xff),
            };
        }

        const const_mask = 0xe00_0000;
        const fixed_bits = 0x800_0000;
    };

    pub const Swap = struct {
        cond: Cond,

        b: op_bits.ByteWord,

        rn: u4,
        rd: u4,
        rm: u4,

        pub fn encode(self: Swap) u32 {
            return fixed_bits |
                self.cond.bits() |
                self.b.bits() |
                @as(u32, self.rn) << 16 |
                @as(u32, self.rd) << 12 |
                self.rm;
        }

        pub fn decode(op: u32) Swap {
            return .{
                .cond = Cond.fromOpcode(op),
                .b = @enumFromInt((op >> 22) & 1),
                .rn = @truncate((op >> 16) & 0xf),
                .rd = @truncate((op >> 12) & 0xf),
                .rm = @truncate(op & 0xf),
            };
        }

        const const_mask = 0xfb0_0ff0;
        const fixed_bits = 0x100_0090;
    };

    pub fn decode(op: u32) Arm {
        // The top 4 bits are the condition,
        // which has no influence on which opcode we decode.
        const trunc: u28 = @truncate(op);

        // Max u28 in hex would be 0xfff_ffff.

        return switch (trunc) {
            0x000_0000...0x3ff_ffff => decodeEarlyOp(op, trunc),
            0x400_0000...0x7ff_ffff => decodeSingleDataTransfer(op),
            0x800_0000...0x9ff_ffff => .{ .block_data_transfer = BlockDataTransfer.decode(op) },
            0xa00_0000...0xbff_ffff => .{ .branch_link = BranchLink.decode(op) },
            0xc00_0000...0xeff_ffff => @panic("coprocessor instructions not yet handled"),
            0xf00_0000...0xfff_ffff => @panic("TODO: handle software interrupt"),
        };
    }

    /// Decode an instruction where the two most significant bits
    /// after the condition are both zero.
    fn decodeEarlyOp(op: u32, trunc: u28) Arm {
        // We consistently use the trunc value in this function,
        // with the hopes that the compiler can do some optimizations
        // based on values we inspect on it.
        // The compiler likely won't assume that trunc & op == trunc.

        // Branch and exchange is a special bit pattern.
        // It's a bit hard to tell exactly what the logic is,
        // in terms of how this overlaps other instructions.
        // Hopefully we can find a simpler approach than this one.
        if ((trunc & BranchExchange.const_mask) == BranchExchange.fixed_bits) {
            return .{
                .branch_exchange = BranchExchange.decode(op),
            };
        }

        if ((trunc & Multiply.const_mask) == Multiply.fixed_bits) {
            return .{
                .mul = Multiply.decode(op),
            };
        }

        if ((trunc & MultiplyLong.const_mask) == MultiplyLong.fixed_bits) {
            return .{
                .mull = MultiplyLong.decode(op),
            };
        }

        if ((trunc & Swap.const_mask) == Swap.fixed_bits) {
            return .{
                .swap = Swap.decode(op),
            };
        }

        // Note: if HalfDataTransfer.sh == 0
        // (which is disallowed as that would indicate the SWP instruction)
        // then our HalfDataTransfer would falsely match MultiplyLong's bitmask.
        if ((trunc & HalfDataTransfer.const_mask) == HalfDataTransfer.fixed_bits) {
            return .{
                .half_data_transfer = HalfDataTransfer.decode(op),
            };
        }

        // Section 4.6:
        // "The MRS and MSR instructions are formed from a subset of the Data Processing
        // operations and are implemented using the TEQ, TST, CMN and CMP instructions
        // without the S flag set."
        if ((trunc & (1 << 20)) == 0) {
            // S flag is clear,
            // so now check if the opcode is one of the special cases.
            const opcode_bits: u4 = @truncate((trunc >> 21) & 0xf);

            // It's more straightforward to directly inspect the bits
            // that would make up the opcode,
            // which would normally occupy bits 21-24.
            //
            // 24 23 22 21
            //  1  0  x  0 -> Mrs
            //  1  0  x  1 -> Msr
            //  1  0  x  1 -> MsrFlags

            switch (opcode_bits) {
                0b1000, 0b1010 => return .{
                    .mrs = Mrs.decode(op),
                },
                0b1001, 0b1011 => {
                    if ((trunc & (1 << 16)) > 0) {
                        // This middle bit differentiates Msr from MsrFlags.
                        return .{
                            .msr = Msr.decode(op),
                        };
                    }

                    return .{
                        .msr_flags = MsrFlags.decode(op),
                    };
                },

                else => {}, // Keep going.
            }
        }
        return .{ .data_process = DataProcess.decode(op) };
    }

    fn decodeSingleDataTransfer(op: u32) Arm {
        // TODO: this isn't quite right,
        // it should return undefined for that specific range in Figure 4-1.
        return .{
            .single_data_transfer = SingleDataTransfer.decode(op),
        };
    }
};

/// Container for types representing specific bits in multiple instructions.
/// If a type is only applicable to a single instruction,
/// it will be inlined in that instruction definition.
const op_bits = struct {
    // It looks like all of these offset arguments are the same across all usages,
    // but let's wait until every instruction is finished before changing them to constants.

    /// P bit used in multiple instructions.
    fn PrePostIndexing(comptime offset: u5) type {
        return enum(u1) {
            post = 0,
            pre = 1,

            fn bits(self: @This()) u32 {
                return @as(u32, @intFromEnum(self)) << offset;
            }
        };
    }

    /// U bit used in multiple instructions.
    fn UpDown(comptime offset: u5) type {
        return enum(u1) {
            down = 0,
            up = 1,

            fn bits(self: @This()) u32 {
                return @as(u32, @intFromEnum(self)) << offset;
            }
        };
    }

    /// L bit used in multiple instructions.
    fn LoadStore(comptime offset: u5) type {
        return enum(u1) {
            store = 0,
            load = 1,

            fn bits(self: @This()) u32 {
                return @as(u32, @intFromEnum(self)) << offset;
            }
        };
    }

    /// P bit indicating whether a status register transfer
    /// is affecting the current or saved PSR.
    fn Psr(comptime offset: u5) type {
        return enum(u1) {
            current = 0,
            saved = 1,

            fn bits(self: @This()) u32 {
                return @as(u32, @intFromEnum(self)) << offset;
            }
        };
    }

    /// Byte or Word bit,
    /// used in SingleDataTransfer and Swap.
    /// Bit 22 in both cases.
    const ByteWord = enum(u1) {
        word = 0,
        byte = 1,

        fn bits(self: @This()) u32 {
            return @as(u32, @intFromEnum(self)) << 22;
        }
    };
};

test {
    _ = @import("./arm_test.zig");
}

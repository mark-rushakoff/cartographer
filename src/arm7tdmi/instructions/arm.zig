pub const Arm = union(enum) {
    branch_exchange: BranchExchange,
    branch_link: BranchLink,
    data_process: DataProcess,

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
                0x012f_ff10 |
                @as(u32, self.rn);
        }

        pub fn decode(op: u32) BranchExchange {
            return .{
                .cond = Cond.fromOpcode(op),
                .rn = @truncate(op & 0xf),
            };
        }
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
        src: enum(u1) {
            current = 0,
            saved = 1,
        },
        rd: u4,

        pub fn encode(self: Mrs) u32 {
            return self.cond.bits() |
                1 << 24 |
                @as(u32, @intFromEnum(self.src)) << 22 |
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
        dst: enum(u1) {
            current = 0,
            saved = 1,
        },
        rm: u4,

        pub fn encode(self: Msr) u32 {
            return self.cond.bits() |
                1 << 24 |
                @as(u32, @intFromEnum(self.dst)) << 22 |
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
        dst: enum(u1) {
            current = 0,
            saved = 1,
        },
        op: Operand,

        pub const Operand = union(enum) {
            register: struct {
                rm: u4,

                pub fn bits(self: @This()) u12 {
                    return self.rm;
                }
            },
            immediate: struct { // TODO: should this be value to match DataProcess.value?
                rot: u4,
                imm: u8,

                pub fn bits(self: @This()) u12 {
                    return @as(u12, self.rot) << 8 |
                        self.imm;
                }
            },

            pub fn bits(self: @This()) u32 {
                return switch (self) {
                    .register => @as(u32, self.register.bits()),
                    .immediate => 1 << 25 | @as(u32, self.immediate.bits()),
                };
            }
        };

        pub fn encode(self: Mrs) u32 {
            return self.cond.bits() |
                1 << 24 |
                @as(u32, @intFromEnum(self.src)) << 22 |
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

    pub fn decode(op: u32) Arm {
        // The top 4 bits are the condition,
        // which has no influence on which opcode we decode.
        const trunc: u28 = @truncate(op);

        // Max u28 in hex would be 0xfff_ffff.

        return switch (trunc) {
            // TODO: Handle full u28 range here.

            0x000_0000...0x3ff_ffff => decodeEarlyOp(op, trunc),

            0xa00_0000...0xbff_ffff => .{ .branch_link = BranchLink.decode(op) },

            else => @panic("Unknown ARM instruction"),
        };
    }

    /// Decode an instruction where the two most significant bits
    /// after the condition are both zero.
    fn decodeEarlyOp(op: u32, trunc: u28) Arm {
        // Branch and exchange is a special bit pattern.
        // It's a bit hard to tell exactly what the logic is,
        // in terms of how this overlaps other instructions.
        // Hopefully we can find a simpler approach than this one.
        if ((trunc & 0x3ff_fff0) == 0x12f_ff10) {
            return .{
                .branch_exchange = BranchExchange.decode(op),
            };
        }

        // Section 4.6:
        // "The MRS and MSR instructions are formed from a subset of the Data Processing
        // operations and are implemented using the TEQ, TST, CMN and CMP instructions
        // without the S flag set."
        if ((trunc & (1 << 20)) == 0) {
            // S flag is clear.
            const opcode: DataProcess.OpCode = @enumFromInt((trunc >> 21) & 0xf);

            switch (opcode) {
                // TODO: handle these four special cases,
                // however they map to MSR and MRS.
                .teq => {},
                .tst => {},
                .cmn => {},
                .cmp => {},

                else => {},
            }
        }
        return .{ .data_process = DataProcess.decode(op) };
    }
};

test {
    _ = @import("./arm_test.zig");
}

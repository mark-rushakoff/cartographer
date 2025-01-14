pub const Arm = union(enum) {
    branch_exchange: BranchExchange,

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
    };
};

const testing = @import("std").testing;

test "Cond.fromOpcode" {
    const al_op = (Arm.BranchExchange{
        .cond = .al,
        .rn = 4,
    }).encode();

    const cond = Arm.Cond.fromOpcode(al_op);
    try testing.expectEqual(.al, cond);
}

test "BranchExchange.encode" {
    // bx r4
    const op = Arm.BranchExchange{
        .cond = .al,
        .rn = 4,
    };
    try testing.expectEqual(0xe12f_ff14, op.encode());
}

test "BranchLink.encode" {
    // blcc  0x12340
    const op = Arm.BranchLink{
        .cond = .cc,
        .l = .link,
        .offset = (0x12340 << 1) - 8,
    };
    try testing.expectEqual(0x3b02_4678, op.encode());
}

const Arm = @import("./arm.zig").Arm;
const testing = @import("std").testing;
const ctest = @import("ctest");

test "Cond.fromOpcode" {
    const al_op = (Arm.BranchExchange{
        .cond = .al,
        .rn = 4,
    }).encode();

    const cond = Arm.Cond.fromOpcode(al_op);
    try testing.expectEqual(.al, cond);
}

test "BranchExchange encode/decode" {
    // bx r4
    const op = Arm.BranchExchange{
        .cond = .al,
        .rn = 4,
    };
    const code = 0xe12f_ff14;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Arm.decode(code).branch_exchange);
}

test "BranchLink encode/decode" {
    // blcc  0x12340
    const op = Arm.BranchLink{
        .cond = .cc,
        .l = .link,
        .offset = (0x12340 << 1) - 8,
    };
    const code = 0x3b02_4678;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Arm.decode(code).branch_link);
}

test "DataProcess encode/decode" {
    // addeq r2, r4, r5
    const op_add = Arm.DataProcess{
        .cond = .eq,
        .opcode = .add,
        .s = 0,
        .rn = 4,
        .rd = 2,
        .op = .{
            .register = .{
                .shift = 0,
                .rm = 5,
            },
        },
    };
    const code_add: u32 =
        // Cond is 0.
        // The operand is a register, so i is 0.
        (4 << 21) | // Add opcode.
        // s is 0.
        (4 << 16) | // rn.
        (2 << 12) | // rd.
        // Shift is 0.
        5; // op:rm.

    try ctest.expectEqualHex(code_add, op_add.encode());
    try testing.expectEqual(op_add, Arm.decode(code_add).data_process);

    // TODO: more configurations of DataProcess.
}

test "Mrs encode/decode" {
    const op = Arm.Mrs{
        .cond = .ne,
        .src = .current,
        .rd = 6,
    };
    const code: u32 =
        Arm.Cond.ne.bits() |
        1 << 24 |
        // src is 0.
        0xf << 16 |
        6 << 12; // rd.
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Arm.decode(code).mrs);
}

test "Msr encode/decode" {
    const op = Arm.Msr{
        .cond = .hi,
        .dst = .saved,
        .rm = 9,
    };
    const code: u32 =
        Arm.Cond.hi.bits() |
        1 << 24 |
        1 << 22 | // dst is 1.
        0x29f << 12 |
        9; // rm.
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Arm.decode(code).msr);
}

test "MsrFlags encode/decode" {
    const op = Arm.MsrFlags{
        .cond = .mi,
        .dst = .saved,
        .op = .{
            .immediate = .{ .rot = 3, .imm = 123 },
        },
    };
    const code: u32 =
        Arm.Cond.mi.bits() |
        1 << 25 | // i=1 for immediate.
        1 << 24 |
        1 << 22 | // dst is 1.
        0x128f << 12 |
        3 << 8 | // Rotate.
        123; // Immediate.
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Arm.decode(code).msr_flags);
}

test "Multiply encode/decode" {
    const op_mul = Arm.Multiply{
        .cond = .pl,
        .a = 0,
        .s = 1,

        .rd = 3,
        .rn = 0,
        .rs = 4,
        .rm = 5,
    };
    const code_mul: u32 =
        Arm.Cond.pl.bits() |
        // a is 0.
        1 << 20 | // s=1.
        3 << 16 | // rd=3.
        // rn=0.
        4 << 8 | // rn=4.
        9 << 4 | // Constant bits.
        5; // rm.
    try ctest.expectEqualHex(code_mul, op_mul.encode());
    try testing.expectEqual(op_mul, Arm.decode(code_mul).mul);
}

test "MultiplyLong encode/decode" {
    const op_mul = Arm.MultiplyLong{
        .cond = .lt,
        .sign = .unsigned,
        .a = 1,
        .s = 0,

        .rd_hi = 8,
        .rd_lo = 9,
        .rs = 10,
        .rm = 11,
    };
    const code_mul: u32 =
        Arm.Cond.lt.bits() |
        1 << 23 | // Constant bit.
        // u (unsigned) is 0.
        1 << 21 | // a=1.
        // s=0.
        8 << 16 | // rdhi=8.
        9 << 12 | // rdlo=9.
        10 << 8 | // rs=10.
        9 << 4 | // Constant bits.
        11; // rm.
    try ctest.expectEqualHex(code_mul, op_mul.encode());
    try testing.expectEqual(op_mul, Arm.decode(code_mul).mull);
}

test "SingleDataTransfer encode/decode" {
    const op_reg = Arm.SingleDataTransfer{
        .cond = .gt,
        .p = .pre,
        .u = .up,
        .b = .word,
        .w = 1,

        .l = .store,

        .rn = 3,
        .rd = 7,

        .offset = .{
            .reg = .{
                .shift = 123,
                .rm = 2,
            },
        },
    };
    const code_reg: u32 =
        Arm.Cond.gt.bits() |
        1 << 26 | // Constant bit.
        1 << 25 | // i=1 for register offset.
        1 << 24 | // p=1.
        1 << 23 | // u=1.
        // b=0.
        1 << 21 | // w=1.
        // l=0.
        3 << 16 | // rn=3.
        7 << 12 | // rd=7.
        123 << 4 | // Shift.
        2; // rm.
    try ctest.expectEqualHex(code_reg, op_reg.encode());
    try testing.expectEqual(op_reg, Arm.decode(code_reg).single_data_transfer);
}

test "HalfDataTransfer encode/decode" {
    const op_swp: Arm.HalfDataTransfer = .{
        .cond = .ls,
        .p = .post,
        .u = .up,
        .w = 1,
        .l = .store,
        .rn = 1,
        .rd = 6,
        .sh = .s_byte,
        .offset = .{
            .rm = 11,
        },
    };
    const code_swp: u32 =
        Arm.Cond.ls.bits() |
        // p=0
        1 << 23 | // u=1.
        1 << 21 | // w=1.
        // l=0
        1 << 16 | // rn=1.
        6 << 12 | // rd=6.
        9 << 4 | // Constant bits.
        2 << 5 | // sh=signed byte.
        11; // rm=11.
    try ctest.expectEqualHex(code_swp, op_swp.encode());
    try testing.expectEqual(op_swp, Arm.decode(code_swp).half_data_transfer);

    // TODO: test for offset=immediate.
}

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

// TODO: Mrs, Msr, MsrFlags tests.

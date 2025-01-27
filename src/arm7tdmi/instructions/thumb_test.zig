const Thumb = @import("./thumb.zig").Thumb;
const testing = @import("std").testing;
const ctest = @import("ctest");

// All of the following tests are using instructions observed in the wild with a disassembler.

test "MoveShifted.encode" {
    // Logical shift left, r1, by 2, storing in r0.
    const op = Thumb.MoveShifted{
        .op = .lsl,
        .offset = 2,
        .rs = 1,
        .rd = 0,
    };

    const code = 0x0088;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).move_shifted);
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

    const code = 0x1930;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).add_subtract);
}

test "Immediate.encode" {
    // mov r6, #1
    const op = Thumb.Immediate{
        .op = .mov,
        .rd = 6,
        .val = 1,
    };

    const code = 0x2601;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).immediate);
}

test "Alu.encode" {
    // cmp r6, r0
    // (cmp rd, rs)
    const op = Thumb.Alu{
        .op = .cmp,
        .rd = 6,
        .rs = 0,
    };

    const code = 0x4286;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).alu);
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

    const code = 0x4657;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).hi_register);
}

test "PcLoad.encode" {
    // ldr r5, [pc, #0xb0]
    // (ldr rd, [pc, #imm])
    const op = Thumb.PcLoad{
        .rd = 5,

        // "the assembler places #Imm >> 2 in field [val]"
        .val = 0xb0 >> 2,
    };

    const code = 0x4d2c;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).pc_load);
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

    const code = 0x5193;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).reg_offset);
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

    const code = 0x5668;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).mem_sign);
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

    const code = 0x60c1;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).mem_offset);
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

    const code = 0x88e1;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).mem_halfword);
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

    const code = 0x9102;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).access_sp);
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

    const code = 0xad03;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).load);
}

test "AdjustSp.encode" {
    // add sp, #0x18
    // (add sp, #imm)
    const op_add = Thumb.AdjustSp{
        .op = .add,
        .offset = 0x18 >> 2,
    };

    const code_add = 0xb006;
    try ctest.expectEqualHex(code_add, op_add.encode());
    try testing.expectEqual(op_add, Thumb.decode(code_add).adjust_sp);

    // sub sp, #0x18
    // (sub sp, #imm)
    const op_sub = Thumb.AdjustSp{
        .op = .sub,
        .offset = 0x18 >> 2,
    };

    const code_sub = 0xb086;
    try ctest.expectEqualHex(code_sub, op_sub.encode());
    try testing.expectEqual(op_sub, Thumb.decode(code_sub).adjust_sp);
}

test "Stack.encode" {
    // pop {r4, r5, r6, r7}
    // (pop {rlist})
    const op_pop = Thumb.Stack{
        .l = .load,
        .r = .no_store,
        .rlist = (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7),
    };

    const code_pop = 0xbcf0;
    try ctest.expectEqualHex(code_pop, op_pop.encode());
    try testing.expectEqual(op_pop, Thumb.decode(code_pop).stack);

    // push {r4, lr}
    // (push {rlist, lr})
    const op_push_lr = Thumb.Stack{
        .l = .store,
        .r = .store,
        .rlist = (1 << 4),
    };

    const code_push = 0xb510;
    try ctest.expectEqualHex(code_push, op_push_lr.encode());
    try testing.expectEqual(op_push_lr, Thumb.decode(code_push).stack);
}

test "MemMultiple.encode" {
    // stmia r0!, {r3-r7}
    // stmia rb!, {rlist}
    const op = Thumb.MemMultiple{
        .l = .store,
        .rb = 0,
        .rlist = (1 << 3) | (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7),
    };

    const code = 0xc0f8;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).mem_multiple);
}

test "CondBranch.encode" {
    // "The branch offset must take account of the prefetch operation,
    // which causes the PCto be 1 word (4 bytes) ahead of the current instruction."

    // bhi +0x20
    const op_forward = Thumb.CondBranch{
        .cond = .hi,
        .offset = (0x20 - 4) >> 1,
    };
    const code_forward = 0xd80e;
    try ctest.expectEqualHex(code_forward, op_forward.encode());
    try testing.expectEqual(op_forward, Thumb.decode(code_forward).cond_branch);

    // bge -0x16
    const op_backward = Thumb.CondBranch{
        .cond = .ge,
        .offset = (-0x16 - 4) >> 1,
    };
    const code_backward = 0xdaf3;
    try ctest.expectEqualHex(code_backward, op_backward.encode());
    try testing.expectEqual(op_backward, Thumb.decode(code_backward).cond_branch);
}

test "SoftwareInterrupt.encode" {
    // swi 0xab
    const op = Thumb.SoftwareInterrupt{
        .val = 0xab,
    };

    const code = 0xdfab;
    try ctest.expectEqualHex(code, op.encode());
    try testing.expectEqual(op, Thumb.decode(code).software_interrupt);
}

test "Branch.encode" {
    // b +0xac
    const op_forward = Thumb.Branch{
        .offset = (0xac - 4) >> 1,
    };
    const code_forward = 0xe054;
    try ctest.expectEqualHex(code_forward, op_forward.encode());
    try testing.expectEqual(op_forward, Thumb.decode(code_forward).branch);

    // b -0x122
    const op_backward = Thumb.Branch{
        .offset = (-0x122 - 4) >> 1,
    };
    const code_backward = 0xe76d;
    try ctest.expectEqualHex(code_backward, op_backward.encode());
    try testing.expectEqual(op_backward, Thumb.decode(code_backward).branch);
}

test "LongBranch.encode" {
    // Upper bits first
    const op_upper = Thumb.LongBranch{
        .h = .high,
        .offset = 0x7ca,
    };
    const code_upper = 0xf7ca;
    try ctest.expectEqualHex(code_upper, op_upper.encode());
    try testing.expectEqual(op_upper, Thumb.decode(code_upper).long_branch);

    const op_lower = Thumb.LongBranch{
        .h = .low,
        .offset = 0xa3,
    };
    const code_lower = 0xf8a3;
    try ctest.expectEqualHex(code_lower, op_lower.encode());
    try testing.expectEqual(op_lower, Thumb.decode(code_lower).long_branch);
}

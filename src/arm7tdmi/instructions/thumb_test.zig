const Thumb = @import("./thumb.zig").Thumb;
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
    try testing.expectEqual(op, Thumb.decode(0x0088).move_shifted);
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

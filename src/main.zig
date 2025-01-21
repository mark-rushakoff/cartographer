const std = @import("std");

const instr = @import("arm").instructions;

pub fn main() !void {
    // Arbitrary opcode that happens to be valid ascii.
    const op = (instr.Thumb.RegOffset{
        .l = .load,
        .b = .byte,

        .rd = 1,
        .rb = 7,
        .ro = 1,
    }).encode();

    const c1: u8 = @truncate(op >> 8);
    const c2: u8 = @truncate(op);

    std.debug.print("Encode THUMB: `ldrb r1, [r7, r1]`: {c}{c}\n", .{ c1, c2 });
}

test {
    _ = instr.Arm; // Force reference for now.

    _ = @import("./gba/timers.zig");
    _ = @import("./gba/core.zig").Core;

    std.testing.refAllDeclsRecursive(@This());
}

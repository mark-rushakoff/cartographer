const std = @import("std");

const thumb = @import("./arm7tdmi/instructions/thumb.zig").Thumb;

pub fn main() !void {
    // Totally arbitrary command that prints something in ascii.
    const op = (thumb.RegOffset{
        .l = .load,
        .b = .byte,

        .rd = 1,
        .rb = 7,
        .ro = 1,
    }).encode();

    const c1: u8 = @truncate(op >> 8);
    const c2: u8 = @truncate(op);

    std.debug.print("Encode `ldrb r1, [r7, r1]`: {c}{c}\n", .{ c1, c2 });
}

test {
    std.testing.refAllDecls(@This());
}

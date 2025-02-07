//! Helpers for tests specific to cartographer.

const std = @import("std");

pub fn expectEqualHex(expected: anytype, actual: anytype) !void {
    if (expected != actual) {
        std.debug.print(
            "\nexpected 0x{x}, got 0x{x}\nexpected(binary): 0b{b}\ngot     (binary): 0b{b}\n",
            .{ expected, actual, expected, actual },
        );
        return error.TestExpectedEqual;
    }
}

pub fn expectEqualBinary(expected: anytype, actual: anytype) !void {
    if (expected != actual) {
        std.debug.print("\n.\nexpected: 0b{b}\ngot:      0b{b}\n", .{ expected, actual });
        return error.TestExpectedEqual;
    }
}

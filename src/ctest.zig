//! Helpers for tests specific to cartographer.

const std = @import("std");

pub fn expectEqualHex(expected: anytype, actual: anytype) !void {
    if (expected != actual) {
        std.debug.print("\nexpected 0x{x}, got 0x{x}\n", .{ expected, actual });
        return error.TestExpectedEqual;
    }
}

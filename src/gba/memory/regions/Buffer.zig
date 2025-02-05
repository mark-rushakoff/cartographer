const MemoryRegion = @import("../../MemoryRegion.zig");

const std = @import("std");

/// Buffer returns a new type with the given size and base address.
/// TODO: this probably needs some definition of how to do mirroring.
pub fn Buffer(comptime sz: u32, base_addr: u32) type {
    return struct {
        data: [sz]u8,

        pub const Self = @This();

        pub fn readByte(self: *Self, addr: u32) MemoryRegion.ReadResult(u8) {
            const offset = addr - base_addr;

            return .{
                .addr = addr,
                .value = self.data[offset],
            };
        }

        pub fn readHalf(self: *Self, addr: u32) MemoryRegion.ReadResult(u16) {
            const offset = addr - base_addr;
            const bytes = self.data[offset .. offset + 2];

            return .{
                .addr = addr,
                .value = std.mem.readInt(u16, bytes[0..2], .little),
            };
        }

        pub fn readWord(self: *Self, addr: u32) MemoryRegion.ReadResult(u32) {
            const offset = addr - base_addr;
            const bytes = self.data[offset .. offset + 4];

            return .{
                .addr = addr,
                .value = std.mem.readInt(u32, bytes[0..4], .little),
            };
        }

        pub fn writeByte(self: *Self, addr: u32, val: u8) MemoryRegion.WriteResult(u8) {
            const offset = addr - base_addr;

            const old_val = self.data[offset];
            self.data[offset] = val;

            return .{
                .addr = addr,
                .old_value = old_val,
                .new_value = val,
            };
        }

        pub fn writeHalf(self: *Self, addr: u32, val: u16) MemoryRegion.WriteResult(u16) {
            const offset = addr - base_addr;

            const bytes = self.data[offset .. offset + 2];
            const old_val = std.mem.readInt(u16, bytes[0..2], .little);

            std.mem.writeInt(u16, bytes[0..2], val, .little);

            return .{
                .addr = addr,
                .old_value = old_val,
                .new_value = val,
            };
        }

        pub fn writeWord(self: *Self, addr: u32, val: u32) MemoryRegion.WriteResult(u32) {
            const offset = addr - base_addr;

            const bytes = self.data[offset .. offset + 4];
            const old_val = std.mem.readInt(u32, bytes[0..4], .little);

            std.mem.writeInt(u32, bytes[0..4], val, .little);

            return .{
                .addr = addr,
                .old_value = old_val,
                .new_value = val,
            };
        }
    };
}

const testing = std.testing;

test "basic behavior" {
    const sz: u32 = 8;
    const base_addr: u32 = 0;
    const Buf8 = Buffer(sz, base_addr);

    var r = Buf8{
        .data = .{ 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80 },
    };
    const mr = MemoryRegion.init(&r);

    // Reads.
    try testing.expectEqual(MemoryRegion.ReadResult(u8){ .addr = 3, .value = 0x40 }, mr.readByte(3));
    try testing.expectEqual(MemoryRegion.ReadResult(u16){ .addr = 2, .value = 0x4030 }, mr.readHalf(2));
    try testing.expectEqual(MemoryRegion.ReadResult(u32){ .addr = 4, .value = 0x80706050 }, mr.readWord(4));

    // Writes with reads.
    try testing.expectEqual(
        MemoryRegion.WriteResult(u8){ .addr = 1, .old_value = 0x20, .new_value = 0x21 },
        mr.writeByte(1, 0x21),
    );
    try testing.expectEqual(MemoryRegion.ReadResult(u8){ .addr = 1, .value = 0x21 }, mr.readByte(1));

    try testing.expectEqual(
        MemoryRegion.WriteResult(u16){ .addr = 2, .old_value = 0x4030, .new_value = 0xabcd },
        mr.writeHalf(2, 0xabcd),
    );
    try testing.expectEqual(MemoryRegion.ReadResult(u16){ .addr = 2, .value = 0xabcd }, mr.readHalf(2));

    try testing.expectEqual(
        MemoryRegion.WriteResult(u32){ .addr = 4, .old_value = 0x80706050, .new_value = 0x01234567 },
        mr.writeWord(4, 0x01234567),
    );
    try testing.expectEqual(MemoryRegion.ReadResult(u32){ .addr = 4, .value = 0x01234567 }, mr.readWord(4));

    // And after all that, the data is laid out as expected.
    try testing.expect(
        std.mem.eql(
            u8,
            &r.data,
            &[8]u8{ 0x10, 0x21, 0xcd, 0xab, 0x67, 0x45, 0x23, 0x01 },
        ),
    );
}

test "non-zero base address" {
    const base_addr: u32 = 0x0100_0000;
    const Buf81 = Buffer(8, base_addr);

    var r = Buf81{
        .data = .{ 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80 },
    };
    const mr = MemoryRegion.init(&r);

    const addr = 0x0100_0006;
    try testing.expectEqual(
        MemoryRegion.ReadResult(u8){ .addr = addr, .value = 0x70 },
        mr.readByte(addr),
    );
}

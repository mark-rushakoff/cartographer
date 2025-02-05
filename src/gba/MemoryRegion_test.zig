const MemoryRegion = @import("./MemoryRegion.zig");

const std = @import("std");

/// 8-byte region, with mirroring, for test.
/// Oversimplified and probably breaks some basic principles,
/// but fine for some tests.
/// This is going to be replaced by a BufferRegion soon.
pub const Region8 = struct {
    data: [8]u8,

    pub fn readByte(self: *Region8, addr: u32) MemoryRegion.ReadResult(u8) {
        const idx = addr % 8;

        return .{
            .addr = addr,
            .value = self.data[idx],
        };
    }

    pub fn readHalf(self: *Region8, addr: u32) MemoryRegion.ReadResult(u16) {
        const idx = addr % 8;
        const bytes = self.data[idx .. idx + 2];

        return .{
            .addr = addr,
            .value = std.mem.readInt(u16, bytes[0..2], .little),
        };
    }

    pub fn readWord(self: *Region8, addr: u32) MemoryRegion.ReadResult(u32) {
        const idx = addr % 8;
        const bytes = self.data[idx .. idx + 4];

        return .{
            .addr = addr,
            .value = std.mem.readInt(u32, bytes[0..4], .little),
        };
    }

    pub fn writeByte(self: *Region8, addr: u32, val: u8) MemoryRegion.WriteResult(u8) {
        const idx = addr % 8;

        const old_val = self.data[idx];
        self.data[idx] = val;

        return .{
            .addr = addr,
            .old_value = old_val,
            .new_value = val,
        };
    }

    pub fn writeHalf(self: *Region8, addr: u32, val: u16) MemoryRegion.WriteResult(u16) {
        const idx = addr % 8;

        const bytes = self.data[idx .. idx + 2];
        const old_val = std.mem.readInt(u16, bytes[0..2], .little);

        std.mem.writeInt(u16, bytes[0..2], val, .little);

        return .{
            .addr = addr,
            .old_value = old_val,
            .new_value = val,
        };
    }

    pub fn writeWord(self: *Region8, addr: u32, val: u32) MemoryRegion.WriteResult(u32) {
        const idx = addr % 8;

        const bytes = self.data[idx .. idx + 4];
        const old_val = std.mem.readInt(u32, bytes[0..4], .little);

        std.mem.writeInt(u32, bytes[0..4], val, .little);

        return .{
            .addr = addr,
            .old_value = old_val,
            .new_value = val,
        };
    }
};

const testing = std.testing;

test {
    var r = Region8{
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

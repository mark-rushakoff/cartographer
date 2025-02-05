const MemoryRegion = @import("../../MemoryRegion.zig");
const ReadRequest = MemoryRegion.ReadRequest;
const ReadResult = MemoryRegion.ReadResult;
const WriteRequest = MemoryRegion.WriteRequest;
const WriteResult = MemoryRegion.WriteResult;

const std = @import("std");

/// Buffer returns a new type with the given size and base address.
/// TODO: this probably needs some definition of how to do mirroring.
pub fn Buffer(comptime sz: u32, base_addr: u32) type {
    return struct {
        data: [sz]u8,

        pub const Self = @This();

        pub fn readByte(self: *Self, req: ReadRequest) ReadResult(u8) {
            const offset = req.addr - base_addr;

            return .{
                .addr = req.addr,
                .value = self.data[offset],
            };
        }

        pub fn readHalf(self: *Self, req: ReadRequest) ReadResult(u16) {
            const offset = req.addr - base_addr;
            const bytes = self.data[offset .. offset + 2];

            return .{
                .addr = req.addr,
                .value = std.mem.readInt(u16, bytes[0..2], .little),
            };
        }

        pub fn readWord(self: *Self, req: ReadRequest) ReadResult(u32) {
            const offset = req.addr - base_addr;
            const bytes = self.data[offset .. offset + 4];

            return .{
                .addr = req.addr,
                .value = std.mem.readInt(u32, bytes[0..4], .little),
            };
        }

        pub fn writeByte(self: *Self, req: WriteRequest(u8)) WriteResult(u8) {
            const offset = req.addr - base_addr;

            const old_val = self.data[offset];
            self.data[offset] = req.value;

            return .{
                .addr = req.addr,
                .old_value = old_val,
                .new_value = req.value,
            };
        }

        pub fn writeHalf(self: *Self, req: WriteRequest(u16)) WriteResult(u16) {
            const offset = req.addr - base_addr;

            const bytes = self.data[offset .. offset + 2];
            const old_val = std.mem.readInt(u16, bytes[0..2], .little);

            std.mem.writeInt(u16, bytes[0..2], req.value, .little);

            return .{
                .addr = req.addr,
                .old_value = old_val,
                .new_value = req.value,
            };
        }

        pub fn writeWord(self: *Self, req: WriteRequest(u32)) WriteResult(u32) {
            const offset = req.addr - base_addr;

            const bytes = self.data[offset .. offset + 4];
            const old_val = std.mem.readInt(u32, bytes[0..4], .little);

            std.mem.writeInt(u32, bytes[0..4], req.value, .little);

            return .{
                .addr = req.addr,
                .old_value = old_val,
                .new_value = req.value,
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
    try testing.expectEqual(
        ReadResult(u8){ .addr = 3, .value = 0x40 },
        mr.readByte(.{ .addr = 3, .requester = .pipeline }),
    );
    try testing.expectEqual(
        ReadResult(u16){ .addr = 2, .value = 0x4030 },
        mr.readHalf(.{ .addr = 2, .requester = .pipeline }),
    );
    try testing.expectEqual(
        ReadResult(u32){ .addr = 4, .value = 0x80706050 },
        mr.readWord(.{ .addr = 4, .requester = .pipeline }),
    );

    // Writes with reads.
    try testing.expectEqual(
        WriteResult(u8){ .addr = 1, .old_value = 0x20, .new_value = 0x21 },
        mr.writeByte(.{ .addr = 1, .value = 0x21, .requester = .cpu }),
    );
    try testing.expectEqual(
        ReadResult(u8){ .addr = 1, .value = 0x21 },
        mr.readByte(.{ .addr = 1, .requester = .cpu }),
    );

    try testing.expectEqual(
        WriteResult(u16){ .addr = 2, .old_value = 0x4030, .new_value = 0xabcd },
        mr.writeHalf(.{ .addr = 2, .value = 0xabcd, .requester = .cpu }),
    );
    try testing.expectEqual(
        ReadResult(u16){ .addr = 2, .value = 0xabcd },
        mr.readHalf(.{ .addr = 2, .requester = .cpu }),
    );

    try testing.expectEqual(
        WriteResult(u32){ .addr = 4, .old_value = 0x80706050, .new_value = 0x01234567 },
        mr.writeWord(.{ .addr = 4, .value = 0x01234567, .requester = .cpu }),
    );
    try testing.expectEqual(
        ReadResult(u32){ .addr = 4, .value = 0x01234567 },
        mr.readWord(.{ .addr = 4, .requester = .cpu }),
    );

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
        mr.readByte(.{ .addr = addr, .requester = .pipeline }),
    );
}

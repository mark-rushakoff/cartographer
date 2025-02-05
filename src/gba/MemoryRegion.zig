const MemoryRegion = @This();

// This structure is following the second example at
// https://zig.news/yglcode/code-study-interface-idiomspatterns-in-zig-standard-libraries-4lkj,
// the "vtable and dynamic dispatching" approach.

ctx: *anyopaque,

vtab: struct {
    readByte: *const fn (ctx: *anyopaque, addr: u32) ReadResult(u8),
    readHalf: *const fn (ctx: *anyopaque, addr: u32) ReadResult(u16),
    readWord: *const fn (ctx: *anyopaque, addr: u32) ReadResult(u32),

    writeByte: *const fn (ctx: *anyopaque, addr: u32, val: u8) WriteResult(u8),
    writeHalf: *const fn (ctx: *anyopaque, addr: u32, val: u16) WriteResult(u16),
    writeWord: *const fn (ctx: *anyopaque, addr: u32, val: u32) WriteResult(u32),
},

// TODO: extract ReadRequest and WriteRequest types.

pub fn readByte(self: MemoryRegion, addr: u32) ReadResult(u8) {
    return self.vtab.readByte(self.ctx, addr);
}

pub fn readHalf(self: MemoryRegion, addr: u32) ReadResult(u16) {
    return self.vtab.readHalf(self.ctx, addr);
}

pub fn readWord(self: MemoryRegion, addr: u32) ReadResult(u32) {
    return self.vtab.readWord(self.ctx, addr);
}

pub fn writeByte(self: MemoryRegion, addr: u32, val: u8) WriteResult(u8) {
    return self.vtab.writeByte(self.ctx, addr, val);
}

pub fn writeHalf(self: MemoryRegion, addr: u32, val: u16) WriteResult(u16) {
    return self.vtab.writeHalf(self.ctx, addr, val);
}

pub fn writeWord(self: MemoryRegion, addr: u32, val: u32) WriteResult(u32) {
    return self.vtab.writeWord(self.ctx, addr, val);
}

pub fn init(region: anytype) MemoryRegion {
    const Ptr = @TypeOf(region);
    const PtrInfo = @typeInfo(Ptr);

    const assert = @import("std").debug.assert;
    assert(PtrInfo == .pointer);
    assert(PtrInfo.pointer.size == .one);
    assert(@typeInfo(PtrInfo.pointer.child) == .@"struct");

    const impl = struct {
        fn readByte(ctx: *anyopaque, addr: u32) ReadResult(u8) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readByte(addr);
        }

        fn readHalf(ctx: *anyopaque, addr: u32) ReadResult(u16) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readHalf(addr);
        }

        fn readWord(ctx: *anyopaque, addr: u32) ReadResult(u32) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readWord(addr);
        }

        fn writeByte(ctx: *anyopaque, addr: u32, val: u8) WriteResult(u8) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeByte(addr, val);
        }

        fn writeHalf(ctx: *anyopaque, addr: u32, val: u16) WriteResult(u16) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeHalf(addr, val);
        }

        fn writeWord(ctx: *anyopaque, addr: u32, val: u32) WriteResult(u32) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeWord(addr, val);
        }
    };

    return .{
        .ctx = region,
        .vtab = .{
            .readByte = impl.readByte,
            .readHalf = impl.readHalf,
            .readWord = impl.readWord,

            .writeByte = impl.writeByte,
            .writeHalf = impl.writeHalf,
            .writeWord = impl.writeWord,
        },
    };
}

/// The result of a read operation on a MemoryRegion.
pub fn ReadResult(comptime T: type) type {
    return struct {
        // The address is not strictly necessary for emulation,
        // but it gives another hook point for debugging.
        addr: u32,

        /// The value that memory wrote back to the reader.
        /// It is possible that a region may send data
        /// different from what is stored at that address,
        /// for example in the case of attempted reads from BIOS.
        value: T,
    };
}

/// The result of a write operation on a MemoryRegion.
pub fn WriteResult(comptime T: type) type {
    return struct {
        // The address is not strictly necessary for emulation,
        // but it gives another hook point for debugging.
        addr: u32,

        // The value at the address prior to the write.
        // Not strictly necessary for emulation,
        // but possibly useful for debugging.
        old_value: T,

        // The newly written value.
        // May not match the value in the write request,
        // if it was a region that disallows writes, for instance.
        new_value: T,
    };
}

test {
    _ = @import("./MemoryRegion_test.zig");
}

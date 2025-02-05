const MemoryRegion = @This();

// This structure is following the second example at
// https://zig.news/yglcode/code-study-interface-idiomspatterns-in-zig-standard-libraries-4lkj,
// the "vtable and dynamic dispatching" approach.

ctx: *anyopaque,

vtab: struct {
    readByte: *const fn (ctx: *anyopaque, req: ReadRequest) ReadResult(u8),
    readHalf: *const fn (ctx: *anyopaque, req: ReadRequest) ReadResult(u16),
    readWord: *const fn (ctx: *anyopaque, req: ReadRequest) ReadResult(u32),

    writeByte: *const fn (ctx: *anyopaque, req: WriteRequest(u8)) WriteResult(u8),
    writeHalf: *const fn (ctx: *anyopaque, req: WriteRequest(u16)) WriteResult(u16),
    writeWord: *const fn (ctx: *anyopaque, req: WriteRequest(u32)) WriteResult(u32),
},

pub fn readByte(self: MemoryRegion, req: ReadRequest) ReadResult(u8) {
    return self.vtab.readByte(self.ctx, req);
}

pub fn readHalf(self: MemoryRegion, req: ReadRequest) ReadResult(u16) {
    return self.vtab.readHalf(self.ctx, req);
}

pub fn readWord(self: MemoryRegion, req: ReadRequest) ReadResult(u32) {
    return self.vtab.readWord(self.ctx, req);
}

pub fn writeByte(self: MemoryRegion, req: WriteRequest(u8)) WriteResult(u8) {
    return self.vtab.writeByte(self.ctx, req);
}

pub fn writeHalf(self: MemoryRegion, req: WriteRequest(u16)) WriteResult(u16) {
    return self.vtab.writeHalf(self.ctx, req);
}

pub fn writeWord(self: MemoryRegion, req: WriteRequest(u32)) WriteResult(u32) {
    return self.vtab.writeWord(self.ctx, req);
}

pub fn init(region: anytype) MemoryRegion {
    const Ptr = @TypeOf(region);
    const PtrInfo = @typeInfo(Ptr);

    const assert = @import("std").debug.assert;
    assert(PtrInfo == .pointer);
    assert(PtrInfo.pointer.size == .one);
    assert(@typeInfo(PtrInfo.pointer.child) == .@"struct");

    const impl = struct {
        fn readByte(ctx: *anyopaque, req: ReadRequest) ReadResult(u8) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readByte(req);
        }

        fn readHalf(ctx: *anyopaque, req: ReadRequest) ReadResult(u16) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readHalf(req);
        }

        fn readWord(ctx: *anyopaque, req: ReadRequest) ReadResult(u32) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.readWord(req);
        }

        fn writeByte(ctx: *anyopaque, req: WriteRequest(u8)) WriteResult(u8) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeByte(req);
        }

        fn writeHalf(ctx: *anyopaque, req: WriteRequest(u16)) WriteResult(u16) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeHalf(req);
        }

        fn writeWord(ctx: *anyopaque, req: WriteRequest(u32)) WriteResult(u32) {
            const self: Ptr = @ptrCast(@alignCast(ctx));
            return self.writeWord(req);
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

/// ReadRequester indicates what component is requesting a read.
/// This is useful for debugging,
/// and for some regions it may influence behavior.
/// For example, the BIOS region only allows the pipeline to read its memory.
pub const ReadRequester = enum {
    pipeline,
    cpu,

    // TODO: DMA
};

/// A memory read request originating from a particular component.
pub const ReadRequest = struct {
    addr: u32,

    requester: ReadRequester,
};

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

/// WriteRequester indicates what component is requesting a write.
/// This is useful for debugging,
/// and for some regions it may influence behavior.
pub const WriteRequester = enum {
    cpu,

    // TODO: DMA
};

/// A request to write a memory value at a particular address,
/// including the value to write and who is requesting the write.
pub fn WriteRequest(comptime T: type) type {
    return struct {
        addr: u32,
        value: T,

        requester: WriteRequester,
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

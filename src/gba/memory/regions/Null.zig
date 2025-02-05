const MemoryRegion = @import("../../MemoryRegion.zig");
const ReadRequest = MemoryRegion.ReadRequest;
const ReadResult = MemoryRegion.ReadResult;
const WriteRequest = MemoryRegion.WriteRequest;
const WriteResult = MemoryRegion.WriteResult;

/// Null fits the MemoryRegion API but panics upon a call to any method.
pub const Null = @This();

pub fn readByte(_: *Null, _: ReadRequest) ReadResult(u8) {
    @panic("calling readByte on Null region disallowed");
}

pub fn readHalf(_: *Null, _: ReadRequest) ReadResult(u16) {
    @panic("calling readHalf on Null region disallowed");
}

pub fn readWord(_: *Null, _: ReadRequest) ReadResult(u32) {
    @panic("calling readWord on Null region disallowed");
}

pub fn writeByte(_: *Null, _: WriteRequest(u8)) WriteResult(u8) {
    @panic("calling writeByte on Null region disallowed");
}

pub fn writeHalf(_: *Null, _: WriteRequest(u16)) WriteResult(u16) {
    @panic("calling writeHalf on Null region disallowed");
}

pub fn writeWord(_: *Null, _: WriteRequest(u32)) WriteResult(u32) {
    @panic("calling writeWord on Null region disallowed");
}

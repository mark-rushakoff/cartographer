const MemoryRegion = @import("../../MemoryRegion.zig");

/// Null fits the MemoryRegion API but panics upon a call to any method.
pub const Null = @This();

pub fn readByte(_: *Null, _: u32) MemoryRegion.ReadResult(u8) {
    @panic("calling readByte on Null region disallowed");
}

pub fn readHalf(_: *Null, _: u32) MemoryRegion.ReadResult(u16) {
    @panic("calling readHalf on Null region disallowed");
}

pub fn readWord(_: *Null, _: u32) MemoryRegion.ReadResult(u32) {
    @panic("calling readWord on Null region disallowed");
}

pub fn writeByte(_: *Null, _: u32, _: u8) MemoryRegion.WriteResult(u8) {
    @panic("calling writeByte on Null region disallowed");
}

pub fn writeHalf(_: *Null, _: u32, _: u16) MemoryRegion.WriteResult(u16) {
    @panic("calling writeHalf on Null region disallowed");
}

pub fn writeWord(_: *Null, _: u32, _: u32) MemoryRegion.WriteResult(u32) {
    @panic("calling writeWord on Null region disallowed");
}

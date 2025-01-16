const result = @import("./memory/result.zig");
const region = @import("./memory/region.zig");

pub const ReadResult = result.ReadResult;
pub const WriteResult = result.WriteResult;

/// New accepts a set of memory regions and produces a new memory type
/// representing all the available memory addresses.
pub fn New(
    regions: anytype,
) type {
    const Self = @This();

    return struct {
        bios: @TypeOf(regions.Bios),
        ew_ram: @TypeOf(regions.EwRam),
        iw_ram: @TypeOf(regions.IwRam),
        io_ram: @TypeOf(regions.IoRam),
        palette_ram: @TypeOf(regions.PaletteRam),
        vram: @TypeOf(regions.vram),
        oam: @TypeOf(regions.oam),
        game_pak: @TypeOf(regions.GamePak),

        /// Initialize with explicit region values.
        pub fn init(
            regions_: anytype,
        ) Self {
            return .{
                .bios = regions_.bios,
                .ew_ram = regions_.ew_ram,
                .iw_ram = regions_.iw_ram,
                .io_ram = regions_.io_ram,
                .palette_ram = regions_.palette_ram,
                .vram = regions_.vram,
                .oam = regions_.oam,
                .game_pak = regions_.game_pak,
            };
        }

        /// Read a byte from the given address,
        /// delegating to the appropriate subsystem.
        pub fn readByte(self: *Self, addr: u32) !ReadResult(u8) {
            return switch (addr) {
                region.sys_start...region.sys_end => self.bios.readByte(addr),
                region.ew_ram_start...region.ew_ram_end => self.ew_ram.readByte(addr),
                region.iw_ram_start...region.iw_ram_end => self.iw_ram.readByte(addr),
                region.io_ram_start...region.io_ram_end => self.io_ram.readByte(addr),
                region.palette_ram_start...region.palette_ram_end => self.palette_ram.readByte(addr),
                region.vram_start...region.vram_end => self.vram.readByte(addr),
                region.oam_start...region.oam_end => self.oam.readByte(addr),
                region.game_pak_start...region.game_pak_end => self.game_pak.readByte(addr),
            };
        }

        pub fn writeByte(self: *Self, addr: u32, val: u8) !WriteResult {
            return switch (addr) {
                region.sys_start...region.sys_end => self.bios.writeByte(addr, val),
                region.ew_ram_start...region.ew_ram_end => self.ew_ram.writeByte(addr, val),
                region.iw_ram_start...region.iw_ram_end => self.iw_ram.writeByte(addr, val),
                region.io_ram_start...region.io_ram_end => self.io_ram.writeByte(addr, val),
                region.palette_ram_start...region.palette_ram_end => self.palette_ram.writeByte(addr, val),
                region.vram_start...region.vram_end => self.vram.writeByte(addr, val),
                region.oam_start...region.oam_end => self.oam.writeByte(addr),
                region.game_pak_start...region.game_pak_end => self.game_pak.writeByte(addr),
            };
        }

        // TODO: read and write, half and full words.
    };
}

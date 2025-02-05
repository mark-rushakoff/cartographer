pub const sys_start: u32 = 0;
pub const sys_end: u32 = ew_ram_start - 1;

pub const ew_ram_start: u32 = 0x02000000;
pub const ew_ram_end: u32 = iw_ram_start - 1;

pub const iw_ram_start: u32 = 0x03000000;
pub const iw_ram_end: u32 = io_ram_start - 1;

pub const io_ram_start: u32 = 0x04000000;
pub const io_ram_end: u32 = palette_ram_start - 1;

pub const palette_ram_start: u32 = 0x05000000;
pub const palette_ram_end: u32 = vram_start - 1;

pub const vram_start: u32 = 0x06000000;
pub const vram_end: u32 = oam_start - 1;

pub const oam_start: u32 = 0x07000000;
pub const oam_end: u32 = game_pak_start - 1;

pub const game_pak_start: u32 = 0x08000000;
pub const game_pak_end: u32 = 0xffffffff;

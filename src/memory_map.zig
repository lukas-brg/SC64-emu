pub const screen_mem_start = 0x0400;
pub const screen_mem_end = 0x07E7;

pub const color_mem_start = 0xD800;
pub const color_mem_end = 0xDBE7;

pub const cursor_row = 0xD6;
pub const cursor_col = 0xD3;

pub const character_rom_start = 0xD000;
pub const io_ram_start = 0xD000;
pub const character_rom_end = 0xDFFF;

pub const kernal_rom_start = 0xE000;
pub const kernal_rom_end = 0xFFFF;

pub const basic_rom_start = 0xA000;
pub const basic_rom_end = 0xBFFF;

pub const bg_color = 0xD021;
pub const text_color = 0x0286;
pub const frame_color = 0xD020;

pub const raster_line_reg = 0xD012;

pub const processor_port = 1;

pub const cia1_start = 0xDC00;
pub const cia1_mirrored_start = 0xDC10;
pub const cia1_end = 0xDCFF;

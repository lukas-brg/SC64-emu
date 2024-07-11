const r = @import("renderer.zig");
const b = @import("bus.zig");
const emu = @import("emulator.zig");
const colors = @import("colors.zig");
const bitutils = @import("cpu/bitutils.zig");

const MemoryMap = b.MemoryMap;
const Bus = b.Bus;


pub const BORDER_SIZE_X = 14;
pub const BORDER_SIZE_Y = 12;

pub const SCREEN_WIDTH = 320;
pub const SCREEN_HEIGHT = 200;


pub const VicII = struct {
    renderer: r.Renderer,
    bus: *b.Bus,
    frame_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 3]u8,
    n_frames_rendered: usize = 0,

    pub fn init(bus: *b.Bus, scaling_factor: f32) VicII {
        
        const renderer = r.Renderer.init(scaling_factor);
        const frame_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 3]u8 = undefined;
    
        var vic: VicII = .{
            .renderer = renderer,
            .bus = bus,
            .frame_buffer = frame_buffer,
        };
        
        vic.clear_color_mem();
        vic.clear_screen_mem();

        return vic;
    }

    pub fn clear_color_mem(self: *VicII) void {
        const bgcolor_code = self.bus.ram[MemoryMap.text_color];
        @memset(
            self.bus.ram[MemoryMap.color_mem_start..MemoryMap.character_rom_end+1],
            bgcolor_code,
        );
    }

    pub fn clear_screen_mem(self: *VicII) void {
        @memset(
            self.bus.ram[MemoryMap.screen_mem_start..MemoryMap.screen_mem_end+1],
            0x20,
        );
    }


    pub fn clear_screen_text_area(self: *VicII) void {
        const color_code: u4 = @truncate(self.bus.read(MemoryMap.bg_color));
        const bg_color = colors.C64_COLOR_PALETTE[color_code];
        for (0..SCREEN_HEIGHT * SCREEN_WIDTH) |i| {
            self.frame_buffer[i * 3] = bg_color.r;
            self.frame_buffer[i * 3 + 1] = bg_color.g;
            self.frame_buffer[i * 3 + 2] = bg_color.b;
        }
    }
    
    
    pub fn update_screen(self: *VicII) void {
       // self.clear_screen_mem();
        self.clear_screen_text_area();
        self.bus.write_io_ram(b.MemoryMap.raster_line_reg, 0); //Todo: This probably shouldn't be here long term, it is a quick and dirty hack to get kernal running for now,
        // as at some point it waits for the rasterline register to reach 0
        var frame_buffer = &self.frame_buffer;
        for (0..MemoryMap.screen_mem_end-MemoryMap.screen_mem_start) |char_count| {
            const screen_mem_addr = char_count + MemoryMap.screen_mem_start;
            const screen_code = @as(u16, self.bus.ram[screen_mem_addr]);
           
            if (screen_code == 0x20) continue;

            const color_mem_addr = char_count + MemoryMap.color_mem_start;
            const color_code: u4 = @truncate(self.bus.ram[color_mem_addr]);
            const color = colors.C64_COLOR_PALETTE[color_code];

            const char_addr_start: u16 = (screen_code * 8);
            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8;
            const char_y = (char_count / 40) * 8;

            for (0..8) |char_row_idx| {
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);

                const char_row_byte = self.bus.character_rom[char_row_addr];

                for (0..8) |char_col_idx| { // The leftmost pixel is represented by the most significant bit
                    const pixel: u1 = bitutils.get_bit_at(char_row_byte, @intCast(7 - char_col_idx));
                    const char_pixel_x = char_x + char_col_idx;
                    const char_pixel_y = char_y + char_row_idx;
                    const fbuf_idx: usize = (char_pixel_y * SCREEN_WIDTH + char_pixel_x) * 3;
                    
                    if (pixel == 1) {
                        frame_buffer[fbuf_idx    ] = color.r;
                        frame_buffer[fbuf_idx + 1] = color.g;
                        frame_buffer[fbuf_idx + 2] = color.b;
                    }
                }
            }
        }

        const border_color = blk: {
            const color_code: u4 = @truncate(self.bus.read(MemoryMap.frame_color));
            break :blk colors.C64_COLOR_PALETTE[color_code];
        };

        self.renderer.render_frame(&self.frame_buffer, border_color);
        self.n_frames_rendered += 1;
    }
};
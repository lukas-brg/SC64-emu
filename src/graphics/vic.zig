const std = @import("std");

const r = @import("renderer.zig");
const b = @import("../bus.zig");
const c = @import("../cpu/cpu.zig");
const emu = @import("../emulator.zig");
const colors = @import("colors.zig");
const bitutils = @import("../cpu/bitutils.zig");
const PrecisionClock = @import("../clock.zig").PrecisionClock;

const MemoryMap = b.MemoryMap;
const Bus = b.Bus;



pub const BORDER_SIZE_X = 14;
pub const BORDER_SIZE_Y = 12;

pub const SCREEN_WIDTH = 320;
pub const SCREEN_HEIGHT = 200;

pub const ROWS = 25;
pub const COLS = 40;




pub const VicII = struct {
    renderer: r.Renderer = undefined,
    bus: *b.Bus,
    frame_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 3]u8,
    n_frames_rendered: usize = 0,
    cpu: *c.CPU,
    scaling_factor: f32,
    termination_requested: bool = false,

    pub fn init(bus: *b.Bus, cpu: *c.CPU, scaling_factor: f32) VicII {
        const frame_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT * 3]u8 = undefined;
    
        var vic: VicII = .{
            .bus = bus,
            .frame_buffer = frame_buffer,
            .cpu = cpu,
            .scaling_factor = scaling_factor,
        };
        
        vic.clearColorMem();
        vic.clearScreenMem();

        return vic;
    }


    pub fn run(self: *VicII, clock: *PrecisionClock) void {
        self.renderer = r.Renderer.init(self.scaling_factor);
        
        while (true) {
            clock.start();
            self.updateScreen();
            if(@atomicLoad(bool, &self.termination_requested, .acquire)) {
                break;
            }
            clock.end();
        }
        std.log.info("Rendering loops exited", .{});
    }

    fn clearColorMem(self: *VicII) void {
        
        self.bus.ram_mutex.lock();
        //const bgcolor_code = self.bus.ram[MemoryMap.text_color];
        const bgcolor_code = self.bus.read(MemoryMap.text_color);
        @memset(
            self.bus.ram[MemoryMap.color_mem_start..MemoryMap.color_mem_end+1],
            bgcolor_code,
        );
        self.bus.ram_mutex.unlock();
    }

    fn clearScreenMem(self: *VicII) void {
        self.bus.mutex.lock();
        defer self.bus.mutex.unlock();
        @memset(
            self.bus.ram[MemoryMap.screen_mem_start..MemoryMap.screen_mem_end+1],
            0x20,
        );
    }


    fn clearScreen(self: *VicII) void {
        const color_code: u4 = @truncate(self.bus.read(MemoryMap.bg_color));
        const bg_color = colors.C64_COLOR_PALETTE[color_code];
        for (0..SCREEN_HEIGHT * SCREEN_WIDTH) |i| {
            self.frame_buffer[i * 3] = bg_color.r;
            self.frame_buffer[i * 3 + 1] = bg_color.g;
            self.frame_buffer[i * 3 + 2] = bg_color.b;
        }
    }
    
    
    pub fn updateScreen(self: *VicII) void {
        self.clearScreen();
      
        //Todo: This probably shouldn't be here long term, it is a quick and dirty hack to get kernal running for now,
        @atomicStore(u8, &self.bus.io_ram[comptime (b.MemoryMap.raster_line_reg - b.MemoryMap.io_ram_start)], 0, .unordered);

        const border_color = blk: {
            const color_code: u4 = @truncate(self.bus.readIORam(MemoryMap.frame_color));
            break :blk colors.C64_COLOR_PALETTE[color_code];
        };
        
        // as at some point it waits for the rasterline register to reach 0
        var frame_buffer = &self.frame_buffer;
        for (0..MemoryMap.screen_mem_end-MemoryMap.screen_mem_start) |char_count| {
            const screen_mem_addr: u16 = @intCast(char_count + MemoryMap.screen_mem_start);
            const color_mem_addr: u16 = @intCast(char_count + MemoryMap.color_mem_start);
                       
            const color_code: u4 = @truncate(self.bus.readIORam(color_mem_addr));
            
            const screen_code = @as(u16, self.bus.readRam(screen_mem_addr));
            if (screen_code == 0x20) continue;
            //std.debug.print("color {any}\n", .{color_code});
            const color = colors.C64_COLOR_PALETTE[color_code];

            const char_addr_start: u16 = (screen_code * 8);
            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8;
            const char_y = (char_count / 40) * 8;

            for (0..8) |char_row_idx| {
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);

                const char_row_byte = self.bus.character_rom[char_row_addr];
   
                for (0..8) |char_col_idx| { // The leftmost pixel is represented by the most significant bit
                    const pixel: u1 = bitutils.getBitAt(char_row_byte, @intCast(7 - char_col_idx));
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

        self.renderer.renderFrame(&self.frame_buffer, border_color);
        self.cpu.irq();
        self.n_frames_rendered += 1;
        if (self.renderer.windowShouldClose()) {
            @atomicStore(
                bool, 
                &self.termination_requested, 
                true, 
                .unordered,
            );
        }
    }
};
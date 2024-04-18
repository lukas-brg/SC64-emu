const std = @import("std");
const CPU = @import("cpu/cpu.zig").CPU;
const DEBUG_CPU = @import("cpu/cpu.zig").DEBUG_CPU;
const Bus = @import("bus.zig").Bus;
const graphics = @import("graphics.zig");
const MemoryMap = @import("bus.zig").MemoryMap;
const bitutils = @import("cpu/bitutils.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});


pub const SCALING_FACTOR = 3;


fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return data;
}


pub const Emulator = struct {

    bus: *Bus,
    cpu: *CPU,
    

    pub fn init(allocator: std.mem.Allocator) !Emulator {
        const bus = try allocator.create(Bus);
        bus.* = Bus.init();

        const cpu = try allocator.create(CPU);
        cpu.* = CPU.init(bus);
        
        const emulator: Emulator = .{
            .bus = bus,
            .cpu = cpu
        };

        return emulator;
    }

    pub fn c64_init(self: *Emulator) !void {
        // load character rom
        try self.load_rom("src/data/c64_charset.bin", 0xD000);  
    }

    pub fn deinit(self: Emulator, allocator: std.mem.Allocator) void {
        allocator.destroy(self.bus);
        allocator.destroy(self.cpu);
    }

    
    pub fn load_rom(self: *Emulator, rom_path: []const u8, offset: u16) !void {

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
    
        const allocator = gpa.allocator();
        const rom_data = try load_file_data(rom_path, allocator);
        self.cpu.bus.write_continous(rom_data, offset);
        allocator.free(rom_data);
    }


    pub fn run(self: *Emulator, limit_cycles: ?usize) !void {
        
        self.cpu.reset();
        var count: usize = 0;
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
            sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        defer sdl.SDL_Quit();

        const screen = sdl.SDL_CreateWindow("My Game Window", sdl.SDL_WINDOWPOS_UNDEFINED, sdl.SDL_WINDOWPOS_UNDEFINED, 320*SCALING_FACTOR, 200*SCALING_FACTOR, sdl.SDL_WINDOW_OPENGL) orelse {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer sdl.SDL_DestroyWindow(screen);
      
        const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
            sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer sdl.SDL_DestroyRenderer(renderer);


        while (!self.cpu.halt) {
            if(limit_cycles) |max_cycles| {
                if(count >= max_cycles) {
                    break;
                }
            }
            if(DEBUG_CPU) {
                self.cpu.bus.print_mem(0, 112);
            }
            
            self.cpu.clock_tick();
            count += 1;
            self.render_frame(renderer);
            break;
        }
        sdl.SDL_Delay(5000);
        _ = sdl.SDL_RenderClear(renderer);
      
        sdl.SDL_RenderPresent(renderer);
     
    }   


    pub fn render_frame(self: *Emulator, renderer: *sdl.struct_SDL_Renderer) void {
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);

        _ = sdl.SDL_RenderClear(renderer);


        sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(50);
        
        var bus = self.bus;
        // 40 cols, 25 rows
    
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_start + 1) |addr| {
            const screen_code = @as(u16, bus.read(@intCast(addr)));
        
            const char_addr_start: u16 = (screen_code * 8) + MemoryMap.character_rom_start;
        
            const char_count = addr - MemoryMap.screen_mem_start;
                   
           
            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8;
            const char_y = (char_count / 40) * 8;
            // std.debug.print("{}\n", .{char_x});
            // std.debug.print("{}\n", .{char_y});
            for(0..8) |char_row_idx|{
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);
                
                const char_row_byte = self.bus.read(char_row_addr);
                std.debug.print("{x}\n", .{char_row_byte});
                for(0..8) |char_col_idx| {
                    const pixel: u1 = bitutils.get_bit_at(char_row_byte, @intCast(char_col_idx));
                    const char_pixel_x: c_int = @intCast(char_x + char_col_idx);
                    const char_pixel_y: c_int = @intCast(char_y + char_row_idx);
                    if (pixel == 1) {

                        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 255, sdl.SDL_ALPHA_OPAQUE);
                        var pixel_rect: sdl.SDL_Rect = .{
                            .x = char_pixel_x * SCALING_FACTOR,
                            .y = char_pixel_y * SCALING_FACTOR,
                            .w = SCALING_FACTOR,
                            .h = SCALING_FACTOR,
                        };

                        _ = sdl.SDL_RenderFillRect(renderer, &pixel_rect);
                        sdl.SDL_RenderPresent(renderer);
                        
                    }
                }

            }
            
        }
    }
        
};
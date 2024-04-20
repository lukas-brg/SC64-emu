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


pub const BORDER_SIZE_X = 14;
pub const BORDER_SIZE_Y = 12;




fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return data;
}


pub const EmulatorConfig = struct {
    headless: bool = false,
    scaling_factor: f16 = 4,
    
};

pub const Emulator = struct {

    bus: *Bus,
    cpu: *CPU,
    config: EmulatorConfig = .{},


    pub fn init(allocator: std.mem.Allocator, config: EmulatorConfig) !Emulator {
        const bus = try allocator.create(Bus);
        bus.* = Bus.init();

        const cpu = try allocator.create(CPU);
        cpu.* = CPU.init(bus);
        const emulator: Emulator = .{
            .bus = bus,
            .cpu = cpu,
            .config = config,
        };

        return emulator;
    }

    pub fn init_c64(self: *Emulator) !void {
        // load character rom
        try self.load_rom("src/data/c64_charset.bin", MemoryMap.character_rom_start);  
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


    pub fn clear_screen_mem(self: *Emulator) void {
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_end) |addr| {
            self.bus.write(@intCast(addr), 0x20);
        }       
    }

    pub fn clear_screen_text_area(renderer: *sdl.struct_SDL_Renderer) void {
        var screen_rect = sdl.SDL_Rect{
            .x = BORDER_SIZE_X,  // Small margin for readability 
            .y = BORDER_SIZE_Y,
            .w = 320,
            .h = 200,
        };

        _ = sdl.SDL_SetRenderDrawColor(renderer, 72,58,170,255);
        _ = sdl.SDL_RenderFillRect(renderer, &screen_rect);
    }
    

 

    pub fn run(self: *Emulator, limit_cycles: ?usize) !void {
        
        self.cpu.reset();
        var count: usize = 0;
        
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
            sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        defer sdl.SDL_Quit();

        const screen = sdl.SDL_CreateWindow("ZIG64 Emulator", 
            sdl.SDL_WINDOWPOS_UNDEFINED, 
            sdl.SDL_WINDOWPOS_UNDEFINED, 
            @intFromFloat(@as(f16, (2*BORDER_SIZE_X+320)) * self.config.scaling_factor), 
            @intFromFloat(@as(f16, (2*BORDER_SIZE_Y+200)) * self.config.scaling_factor), 
            sdl.SDL_WINDOW_OPENGL) 
        orelse {
            sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };

        defer sdl.SDL_DestroyWindow(screen);
      
        const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
            sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer sdl.SDL_DestroyRenderer(renderer);

        _ = sdl.SDL_SetRenderDrawColor(renderer, 134,122,222,255);

        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderSetScale(renderer, self.config.scaling_factor, self.config.scaling_factor);
        
        self.clear_screen_mem();
        var quit = false;
        while (!self.cpu.halt and !quit) {
            var event: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&event) != 0) {
                switch (event.type) {
                    sdl.SDL_QUIT => {
                        quit = true;
                    },
                    else => {},
                }
            }
            
            
            if(limit_cycles) |max_cycles| {
                if(count >= max_cycles) {
                    break;
                }
            }
            if(DEBUG_CPU) {
                self.cpu.bus.print_mem(0x400, 0x20);
            }
            
            self.cpu.clock_tick();
            count += 1;
            self.render_frame(renderer);
            sdl.SDL_RenderPresent(renderer);
            //break;
        }
        //sdl.SDL_Delay(5000);
    }   



    pub fn render_frame(self: *Emulator, renderer: *sdl.struct_SDL_Renderer) void {
 
        clear_screen_text_area(renderer);
        
        var bus = self.bus;
        // 40 cols, 25 rows
    
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_end) |addr| {
            const screen_code = @as(u16, bus.read(@intCast(addr)));
            
            if (screen_code == 0x20) {continue;}
            
            const char_addr_start: u16 = (screen_code * 8) + MemoryMap.character_rom_start;
        
            const char_count = addr - MemoryMap.screen_mem_start;
                   
            _ = sdl.SDL_SetRenderDrawColor(renderer, 134,122,222,255);
           
            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8 + BORDER_SIZE_X;
            const char_y = (char_count / 40) * 8 + BORDER_SIZE_Y;
           
            for(0..8) |char_row_idx|{
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);
                
                const char_row_byte = self.bus.read(char_row_addr);
               
                for(0..8) |char_col_idx|  {
                    const pixel: u1 = bitutils.get_bit_at(char_row_byte,  @intCast(7-char_col_idx));
                    const char_pixel_x: c_int = @intCast(char_x + char_col_idx);
                    const char_pixel_y: c_int = @intCast(char_y + char_row_idx);
                    if (pixel == 1) {
                        _ = sdl.SDL_RenderDrawPoint(renderer, char_pixel_x, char_pixel_y);  
                    }
                }
            }
        }
    }
        
};
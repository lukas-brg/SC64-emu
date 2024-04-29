const std = @import("std");
const CPU = @import("cpu/cpu.zig").CPU;
const DEBUG_CPU = @import("cpu/cpu.zig").DEBUG_CPU;
const Bus = @import("bus.zig").Bus;

const MemoryMap = @import("bus.zig").MemoryMap;
const bitutils = @import("cpu/bitutils.zig");
const colors = @import("colors.zig");

//const sdl = @import("sdl2");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});


pub const FRAME_SIZE_X = 14;
pub const FRAME_SIZE_Y = 12;



const SCREEN_WIDTH = 320;
const SCREEN_HEIGHT = 200;



fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return data;
}


pub const EmulatorConfig = struct {
    headless: bool = true,
    scaling_factor: f16 = 3,    
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
        self.cpu.reset();
        self.cpu.set_reset_vector(0x1000);

        try self.load_basic_rom();
        try self.load_kernal_rom();

        self.bus.write(0, 0x2F); // direction register
        self.bus.write(1, 0x37); // processor port

        //self.bus.write_16(0x0328, 0xF6ED); // stop routine
       
        
        try self.load_rom("data/c64_charset.bin", MemoryMap.character_rom_start);  
        self.bus.write(MemoryMap.bg_color, colors.BG_COLOR);
        self.bus.write(MemoryMap.text_color, colors.TEXT_COLOR);
        self.bus.write(MemoryMap.frame_color, colors.FRAME_COLOR);
        
      //  self.cpu.set_reset_vector(0x1000); // for now write the reset vector into kernal rom as well, after processor port was set

        self.cpu.SP = 0xFF;

        self.clear_color_mem();

    }

    fn load_basic_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
    
        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/basic.bin", allocator);
        @memcpy(self.bus.basic_rom[0..], rom_data);
        allocator.free(rom_data);
    }


    fn load_kernal_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
    
        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/kernal.bin", allocator);
        @memcpy(self.bus.kernal_rom[0..], rom_data);
        allocator.free(rom_data);
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

    pub fn clear_color_mem(self: *Emulator) void {
        for (MemoryMap.color_mem_start..MemoryMap.color_mem_end) |addr| {
            self.bus.write(@intCast(addr), self.bus.read(MemoryMap.text_color));
        }       
    }

    pub fn clear_screen_mem(self: *Emulator) void {
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_end) |addr| {
            self.bus.write(@intCast(addr), 0x20);
        }       
    }

    pub fn clear_screen_text_area(self: *Emulator, frame_buffer: []u8) void {
        const color_code: u4 = @truncate(self.bus.read(MemoryMap.bg_color));
        const bg_color = colors.C64_COLOR_PALETE[color_code];
        for (0..SCREEN_HEIGHT*SCREEN_WIDTH) |i| {
            frame_buffer[i*3] = bg_color.r;
            frame_buffer[i*3+1] = bg_color.g; 
            frame_buffer[i*3+2] = bg_color.b;
        }
    }
    

 

    pub fn run(self: *Emulator, limit_cycles: ?usize) !void {
        self.cpu.reset();
        var count: usize = 0;
        
        const pitch: c_int = SCREEN_WIDTH * 3;
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
            sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        defer sdl.SDL_Quit();

        const screen = sdl.SDL_CreateWindow("ZIG64 Emulator", 
            sdl.SDL_WINDOWPOS_UNDEFINED, 
            sdl.SDL_WINDOWPOS_UNDEFINED, 
            @intFromFloat(@as(f16, (2*FRAME_SIZE_X+320)) * self.config.scaling_factor), 
            @intFromFloat(@as(f16, (2*FRAME_SIZE_Y+200)) * self.config.scaling_factor), 
            sdl.SDL_WINDOW_OPENGL) 
        orelse {
            sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };

     
        defer sdl.SDL_DestroyWindow(screen);
        
      
        const renderer = sdl.SDL_CreateRenderer(screen, -1, sdl.SDL_RENDERER_ACCELERATED) orelse {
            sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };
    
       
        defer sdl.SDL_DestroyRenderer(renderer);
    

        const color_code: u4 = @truncate(self.bus.read(MemoryMap.frame_color));

        const frame_color = colors.C64_COLOR_PALETE[color_code];

        _ = sdl.SDL_SetRenderDrawColor(renderer, frame_color.r, frame_color.g, frame_color.b, 255);

        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderSetScale(renderer, self.config.scaling_factor, self.config.scaling_factor);
        
        const texture = sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_RGB24, sdl.SDL_TEXTUREACCESS_STREAMING, 320, 200) orelse {
            sdl.SDL_Log("Unable to create texture: %s", sdl.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer sdl.SDL_DestroyTexture(texture);

        // if(self.config.headless) {
        //     sdl.SDL_DestroyWindow(screen);
        // }

        var frame_buffer: [3*SCREEN_HEIGHT*SCREEN_WIDTH]u8 = undefined;

        const screen_rect = sdl.SDL_Rect{.w = SCREEN_WIDTH, .h=SCREEN_HEIGHT, .x = FRAME_SIZE_X, .y = FRAME_SIZE_Y};

        self.clear_screen_mem();
        //clear_screen_text_area(&frame_buffer);
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
            
            const mem_window_size = 0x20;
          
            if(DEBUG_CPU) {
                const start: u16 = @intCast(@max(0, @as(i32, @intCast(self.cpu.PC)) - mem_window_size/2));
                const end = @min(self.bus.mem_size, @as(u17, start) + mem_window_size);
                self.cpu.bus.print_mem(start, @intCast(end));
            }

            self.cpu.clock_tick();
            if(!self.config.headless) {
                _ = sdl.SDL_RenderClear(renderer);
                self.clear_screen_text_area(&frame_buffer);
                self.update_frame(&frame_buffer);
            }
            if(limit_cycles) |max_cycles| {
                if(count >= max_cycles) {
                    break;
                }
            }
            count += 1;

            if(!self.config.headless) {
                _ = sdl.SDL_UpdateTexture(texture, null, @ptrCast(&frame_buffer), pitch);
                _ = sdl.SDL_RenderCopy(renderer, texture, null, &screen_rect);
                sdl.SDL_RenderPresent(renderer);
            }
        }
      
    }   



    pub fn update_frame(self: *Emulator, frame_buffer: []u8) void {
       
        var bus = self.bus;
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_end, 
              MemoryMap.color_mem_start..MemoryMap.color_mem_end) 
            
            |screen_mem_addr, color_mem_addr| 
        {
            
            const screen_code = @as(u16, bus.read(@intCast(screen_mem_addr)));
            
            if (screen_code == 0x20) {continue;}
            
            const char_addr_start: u16 = (screen_code * 8) + MemoryMap.character_rom_start;
        
            const char_count = screen_mem_addr - MemoryMap.screen_mem_start;
                   
            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8;
            const char_y = (char_count / 40) * 8;
           
            for(0..8) |char_row_idx|{
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);
                
                const char_row_byte = self.bus.read(char_row_addr);
               
                for(0..8) |char_col_idx|  {                                     // The leftmost pixel is represented by the most significant bit
                    const pixel: u1 = bitutils.get_bit_at(char_row_byte,  @intCast(7-char_col_idx));
                    const char_pixel_x = char_x + char_col_idx;
                    const char_pixel_y = char_y + char_row_idx;

                    const texture_index: usize =  (char_pixel_y * SCREEN_WIDTH + char_pixel_x) * 3;
                    
                    if (pixel == 1) {
                        const color_code: u4 = @truncate(self.bus.read(@intCast(color_mem_addr)));
                        const color = colors.C64_COLOR_PALETE[color_code];
                        frame_buffer[texture_index]   = color.r;
                        frame_buffer[texture_index+1] = color.g; 
                        frame_buffer[texture_index+2] = color.b;
                    }
                    // else {
                    //     const color_code: u4 = @intCast(self.bus.read(@intCast(MemoryMap.bg_color)));
                    //     const color = colors.C64_COLOR_PALETE[color_code];
                    //     frame_buffer[texture_index]   = color.r;
                    //     frame_buffer[texture_index+1] = color.g; 
                    //     frame_buffer[texture_index+2] = color.b;
                    // }
                }
            }
        }
       
    }
        
};
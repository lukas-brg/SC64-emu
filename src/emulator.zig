const std = @import("std");
const CPU = @import("cpu/cpu.zig").CPU;
const DEBUG_CPU = @import("cpu/cpu.zig").DEBUG_CPU;
const Bus = @import("bus.zig").Bus;
const graphics = @import("graphics.zig");
pub const SCALING_FACTOR = 3;


const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

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
            graphics.render_frame(renderer, self);
        }
        _ = sdl.SDL_RenderClear(renderer);
      
        sdl.SDL_RenderPresent(renderer);
     
        sdl.SDL_Delay(17);
    }
      

};
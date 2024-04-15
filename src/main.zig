const std = @import("std");
const c = @import("cpu/cpu.zig");
const Bus = @import("bus.zig").Bus;
const CPU = @import("cpu/cpu.zig").CPU;
const Emulator = @import("emulator.zig").Emulator;
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn load_rom_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const rom_data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return rom_data;
}


pub fn sdl_test() !void {
    
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        sdl.SDL_Log("Unable to initialize SDL: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    const screen = sdl.SDL_CreateWindow("My Game Window", sdl.SDL_WINDOWPOS_UNDEFINED, sdl.SDL_WINDOWPOS_UNDEFINED, 400, 140, sdl.SDL_WINDOW_OPENGL) orelse
        {
        sdl.SDL_Log("Unable to create window: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(screen);

    const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
        sdl.SDL_Log("Unable to create renderer: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    const zig_bmp = @embedFile("zig.bmp");
    const rw = sdl.SDL_RWFromConstMem(zig_bmp, zig_bmp.len) orelse {
        sdl.SDL_Log("Unable to get RWFromConstMem: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer std.debug.assert(sdl.SDL_RWclose(rw) == 0);

    const zig_surface = sdl.SDL_LoadBMP_RW(rw, 0) orelse {
        sdl.SDL_Log("Unable to load bmp: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_FreeSurface(zig_surface);

    const zig_texture = sdl.SDL_CreateTextureFromSurface(renderer, zig_surface) orelse {
        sdl.SDL_Log("Unable to create texture from surface: %s", sdl.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyTexture(zig_texture);

    var quit = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderCopy(renderer, zig_texture, null, null);
        sdl.SDL_RenderPresent(renderer);

        sdl.SDL_Delay(17);
    }
}

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
   
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var rom_path: []const u8 = "test.o65";
    
    if (args.len > 1){
        rom_path = args[1];
    }
    

    var emulator = try Emulator.init(allocator);
    //emulator.cpu.set_reset_vector(0x0040);

    _ = try emulator.load_rom(rom_path, 0);

    emulator.run(null);
    emulator.deinit(allocator);

    _ = try sdl_test();

}


fn test_init_reset_vector(bus: *Bus) void {
    // Reset vector to 0x2010
    bus.write(0xfffc, 0x10);
    bus.write(0xfffd, 0x20);
}

test "loading reset vector into pc" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    test_init_reset_vector(&bus);
    cpu.reset();

    assert(cpu.PC == 0x2010);
}

test "set status flag" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();

    cpu.set_status_flag(c.StatusFlag.BREAK, 1);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.set_status_flag(c.StatusFlag.BREAK, 0);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);
}

test "stack operations" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();
    cpu.push(0x4D);
    assert(cpu.pop() == 0x4D);
}


test "test opcode lookup" {
    const assert = std.debug.assert;
    const decode_opcode = @import("cpu/opcodes.zig").decode_opcode;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();

    const instruction = decode_opcode(0xEA);
    assert(std.mem.eql(u8, instruction.op_name, "NOP"));
}


test "cpu and bus allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
   
    const allocator = gpa.allocator();
    const rom_path: []const u8 = "test.o65";
    var emulator = try Emulator.init(allocator);

    _ = try emulator.load_rom(rom_path, 0);
    
    std.debug.assert(std.mem.eql(u8, &emulator.bus.memory, &emulator.cpu.bus.memory));
    std.debug.assert(emulator.bus == emulator.cpu.bus);

    emulator.run(null);

    std.debug.assert(std.mem.eql(u8, &emulator.bus.memory, &emulator.cpu.bus.memory));
    std.debug.assert(emulator.bus == emulator.cpu.bus);
   
    emulator.deinit(allocator);

    
}
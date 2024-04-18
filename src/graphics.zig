const Emulator = @import("emulator.zig").Emulator;

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});


const SCALING_FACTOR= @import("emulator.zig").SCALING_FACTOR;

pub fn render_frame(renderer: *sdl.struct_SDL_Renderer, emulator: *Emulator) void {
    _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);

    // Clear the entire screen to our selected color.
    _ = sdl.SDL_RenderClear(renderer);

    // Up until now everything was drawn behind the scenes.
    // This will show the new, red contents of the window.
    sdl.SDL_RenderPresent(renderer);
    sdl.SDL_Delay(50);
    const screen_mem = 0x400;
    const character_rom = 0xD000;
    var bus = emulator.bus;
   
    for (screen_mem..0x07E7) |addr| {
        const char_addr = @as(u16, bus.read(@intCast(addr)) * 8) + character_rom;
        _ = char_addr;
    }
}


pub fn sdl_test() !void {
    
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
      
        sdl.SDL_RenderPresent(renderer);

        sdl.SDL_Delay(50);
    }
}
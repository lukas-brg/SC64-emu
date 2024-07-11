const std = @import("std");

const raylib = @import("raylib.zig");

const MemoryMap = @import("bus.zig").MemoryMap;
const colors = @import("colors.zig");

const SCREEN_WIDTH = @import("graphics.zig").SCREEN_WIDTH;
const SCREEN_HEIGHT = @import("graphics.zig").SCREEN_HEIGHT;
const BORDER_SIZE_X = @import("graphics.zig").BORDER_SIZE_X;
const BORDER_SIZE_Y = @import("graphics.zig").BORDER_SIZE_Y;

const log_renderer = std.log.scoped(.renderer);

pub const Renderer = struct {
    scale: f32,
    screen_texture: raylib.struct_Texture = undefined,
    n_frames_rendered: usize = 0,
    __window_close: bool = false,

    pub fn init(scaling_factor: f32) Renderer {
        log_renderer.info("Initializing Renderer...", .{});
        var renderer = Renderer{ .scale = scaling_factor };
        renderer.init_window();
        log_renderer.info("Renderer initialized" ,.{});
        return renderer;
    }

    pub fn window_should_close(self: *Renderer) bool {
        return self.__window_close;
    }

    pub fn init_window(self: *Renderer) void {
        
        const scale = self.scale;
        const win_w: c_int = @intFromFloat((SCREEN_WIDTH + 2 * BORDER_SIZE_X) * scale);
        const win_h: c_int = @intFromFloat((SCREEN_HEIGHT + 2 * BORDER_SIZE_Y) * scale);
        raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
        raylib.InitWindow(win_w, win_h, "SC64 Emulator");

        // center window
        const monitor = raylib.GetCurrentMonitor();
        const monitor_w = raylib.GetMonitorWidth(monitor);
        const monitor_h = raylib.GetMonitorHeight(monitor);
        const x = @divFloor(monitor_w, 2) - @divFloor(win_w, 2);
        const y = @divFloor(monitor_h, 2) - @divFloor(win_h, 2);
        raylib.SetWindowPosition(x, y);

        self.screen_texture = raylib.LoadTextureFromImage(raylib.Image{
            .data = null,
            .width = SCREEN_WIDTH,
            .height = SCREEN_HEIGHT,
            .mipmaps = 1,
            .format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8,
        });

        log_renderer.info("Window created successfully.", .{});
    }

    pub fn render_frame(self: *Renderer, frame_buffer: []u8, border_color: colors.ColorRGB) void {
        if(raylib.WindowShouldClose()) {
            self.__window_close = true;
            return;
        }
        
        raylib.UpdateTexture(self.screen_texture, frame_buffer.ptr);

        const ray_border_color: raylib.Color = .{
            .r = border_color.r,
            .g = border_color.g,
            .b = border_color.b,
            .a = 255,
        };

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(ray_border_color);
        raylib.DrawTextureEx(self.screen_texture, raylib.Vector2{
            .x = BORDER_SIZE_X * self.scale,
            .y = BORDER_SIZE_Y * self.scale,
        }, 0.0, self.scale, raylib.WHITE);
        self.n_frames_rendered += 1;
    }
};

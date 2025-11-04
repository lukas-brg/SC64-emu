const std = @import("std");

const graphics = @import("graphics.zig");
const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const bus = @import("bus.zig");

const log_io = std.log.scoped(.io);
const raylib = graphics.raylib;

const KeyMapping = struct {
    host_key: i32,
    row: u3,
    col: u3,
};

const HostKeyToC64: []const KeyMapping = &.{ 

    KeyMapping{ .host_key = raylib.KEY_A, .row = 2, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_B, .row = 4, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_C, .row = 4, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_D, .row = 2, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_E, .row = 6, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_F, .row = 5, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_G, .row = 2, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_H, .row = 5, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_I, .row = 1, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_J, .row = 2, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_K, .row = 5, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_L, .row = 2, .col = 5 },
    KeyMapping{ .host_key = raylib.KEY_M, .row = 4, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_N, .row = 7, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_O, .row = 6, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_P, .row = 1, .col = 5 },
    KeyMapping{ .host_key = raylib.KEY_Q, .row = 6, .col = 7 },
    KeyMapping{ .host_key = raylib.KEY_R, .row = 1, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_S, .row = 5, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_T, .row = 6, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_U, .row = 6, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_V, .row = 7, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_W, .row = 1, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_X, .row = 7, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_Y, .row = 1, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_Z, .row = 4, .col = 1 },

    KeyMapping{ .host_key = raylib.KEY_SPACE, .row = 4, .col = 7 },
    KeyMapping{ .host_key = raylib.KEY_ENTER, .row = 1, .col = 0 },
    KeyMapping{ .host_key = raylib.KEY_KP_ADD, .row = 0, .col = 5 },


    KeyMapping{ .host_key = raylib.KEY_ONE, .row = 0, .col = 7 },
    KeyMapping{ .host_key = raylib.KEY_TWO, .row = 3, .col = 7 },
    KeyMapping{ .host_key = raylib.KEY_THREE, .row = 0, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_FOUR, .row = 3, .col = 1 },
    KeyMapping{ .host_key = raylib.KEY_FIVE, .row = 0, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_SIX, .row = 3, .col = 2 },
    KeyMapping{ .host_key = raylib.KEY_SEVEN, .row = 0, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_EIGHT, .row = 3, .col = 3 },
    KeyMapping{ .host_key = raylib.KEY_NINE, .row = 0, .col = 4 },
    KeyMapping{ .host_key = raylib.KEY_ZERO, .row = 3, .col = 4 },



};

pub fn update_keyboard_state(emulator: *emu.Emulator) void {
    // _=emulator;
  

    for (HostKeyToC64) |mapping| {
        if (raylib.IsKeyPressed(mapping.host_key)) {
            emulator.cia1.set_key_down(mapping.row, mapping.col);
        } else {
            emulator.cia1.set_key_up(mapping.row, mapping.col);
        }
    }

    // if (raylib.IsKeyPressed(raylib.KEY_A)) {
    //     // emulator.cia1.port_a.* = 0b11111101;
    //     // emulator.cia1.port_b.* = 0b11111011;
    //     emulator.cia1.set_key_down(2, 1);
    //     // emulator.cia1.set_key_down(6, 2);
    //     // emulator.cia1.set_key_down(6, 5);

    //     log_io.debug("A pressed.", .{});
    //     //emulator.__tracing_active = true;
    
    // } else {
    //     emulator.cia1.set_key_up(2, 1);
    // }

    // if (raylib.IsKeyPressed(raylib.KEY_S)) {
    //     // emulator.cia1.port_a.* = 0b11111101;
    //     // emulator.cia1.port_b.* = 0b11111011;
    //     emulator.cia1.set_key_down(5 ,1);
    //     // emulator.cia1.set_key_down(6, 2);
    //     // emulator.cia1.set_key_down(6, 5);

    //     log_io.debug("A pressed.", .{});
    //     //emulator.__tracing_active = true;
    
    // }
    // if (raylib.IsKeyPressed(raylib.KEY_B)) {
    //     // emulator.cia1.port_a.* = 0b11111101;
    //     // emulator.cia1.port_b.* = 0b11111011;
    //     emulator.cia1.set_key_down(4 ,3);
    //     // emulator.cia1.set_key_down(6, 2);
    //     // emulator.cia1.set_key_down(6, 5);

    //     log_io.debug("A pressed.", .{});
    //     //emulator.__tracing_active = true;
    
    
}
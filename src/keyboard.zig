const std = @import("std");

const graphics = @import("graphics.zig");
const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const bus = @import("bus.zig");

const log_io = std.log.scoped(.io);
const raylib = graphics.raylib;

pub fn update_keyboard_state(emulator: *emu.Emulator) void {
    
    
    if (raylib.IsKeyPressed(raylib.KEY_A)) {
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111011;
        log_io.debug("A pressed.", .{});
        //emulator.__tracing_active = true;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_LEFT)) {
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111101;
    } else if (raylib.IsKeyPressed(raylib.KEY_W)) {
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111101;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_E)) {
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b10111111;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_EQUAL)) {
        emulator.cia1.port_a.* = 0b10111111;
        emulator.cia1.port_b.* = 0b11011111;

    } else if (raylib.IsKeyPressed(raylib.KEY_Q)) {
        emulator.cia1.port_a.* = 0b01111111;
        emulator.cia1.port_b.* = 0b10111111;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_ZERO)) {
        emulator.cia1.port_a.* = 0b11101111;
        emulator.cia1.port_b.* = 0b11110111;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_EIGHT)) {
        emulator.cia1.port_a.* = 0b11110111;
        emulator.cia1.port_b.* = 0b11110111;
    
    } else {
        emulator.cia1.port_a.* = 0b11111111;
        emulator.cia1.port_b.* = 0b11111111;
    }
}
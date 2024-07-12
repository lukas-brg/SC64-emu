const std = @import("std");

const raylib = @import("raylib.zig");

const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const bus = @import("bus.zig");

const log_io = std.log.scoped(.io);

pub fn update_keyboard_state(emulator: *emu.Emulator) void {
   
    // const port_a = emulator.bus.read(cia.CiaI.port_a);
    // const port_b = emulator.bus.read(cia.CiaI.port_b);
    if (raylib.IsKeyPressed(raylib.KEY_A)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a,  0b11111101);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b,  0b11111011);
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111011;
        log_io.debug("A pressed.", .{});
        //emulator.__tracing_active = true;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_LEFT)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a,  0b11111101);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b,  0b11111101);
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111101;
    } else if (raylib.IsKeyPressed(raylib.KEY_W)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a,  0b11111101);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b,  0b11111101);
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b11111101;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_E)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a,  0b11111101);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b,  0b10111111);
        emulator.cia1.port_a.* = 0b11111101;
        emulator.cia1.port_b.* = 0b10111111;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_EQUAL)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a, 0b10111111);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b, 0b11011111);
        emulator.cia1.port_a.* = 0b10111111;
        emulator.cia1.port_b.* = 0b11011111;

    } else if (raylib.IsKeyPressed(raylib.KEY_Q)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a, 0b01111111);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b, 0b10111111);
        emulator.cia1.port_a.* = 0b01111111;
        emulator.cia1.port_b.* = 0b10111111;
    
    } else if (raylib.IsKeyPressed(raylib.KEY_ZERO)) {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a, 0b11110111);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b, 0b11110111);
        emulator.cia1.port_a.* = 0b11110111;
        emulator.cia1.port_b.* = 0b11110111;
    
    } else {
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_a, 0b11111111);
        // emulator.bus.write_io_ram(cia.CiaIAddresses.port_b, 0b11111111);
        emulator.cia1.port_a.* = 0b11111111;
        emulator.cia1.port_b.* = 0b11111111;
    }
}
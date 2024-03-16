const std = @import("std");
const Bus = @import("bus.zig").Bus;

pub const StatusFlag = enum(u3) {
    CARRY,
    ZERO,
    INTERRUPT,
    DECIMAL,
    BREAK,
    UNUSED,
    OVERFLOW,
    NEGATIVE,
};

pub const CPU = struct {
    PC: u16,
    SP: u8,
    status: u8,
    A: u8,
    X: u8,
    Y: u8,
    bus: *Bus,

    pub fn init(bus: *Bus) CPU {
        return CPU{
            .PC = 5,
            .SP = 0,
            .status = 0,
            .A = 0,
            .X = 0,
            .Y = 0,
            .bus = bus,
        };
    }

    pub fn print_state(self: CPU) void {
        std.debug.print("\n----------------------------------------------------", .{});
        std.debug.print("\nCPU STATE:", .{});

        std.debug.print("\nPC: {b:0>16}", .{self.PC});
        std.debug.print("\nSP:         {b:0>8}", .{self.SP});
        std.debug.print("\nP:          {b:0>8}", .{self.status});
        std.debug.print("\nA:          {b:0>8}", .{self.A});
        std.debug.print("\nX:          {b:0>8}", .{self.X});
        std.debug.print("\nY:          {b:0>8}", .{self.Y});
        std.debug.print("\n----------------------------------------------------\n", .{});
    }

    pub fn get_status_flag(self: CPU, flag: StatusFlag) bool {
        return ((self.status >> @intFromEnum(flag)) & 1) == 1;
    }

    pub fn clock_tick(self: *CPU) void {
        std.debug.print("{}\n", .{self.bus.read(0)});
    }
};

const std = @import("std");
const Bus = @import("bus.zig").Bus;

const RESET_VECTOR = 0xFFFC;

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
        const cpu = CPU{
            .PC = 0,
            .SP = 0,
            .status = 0,
            .A = 0,
            .X = 0,
            .Y = 0,
            .bus = bus,
        };

        return cpu;
    }

    pub fn reset(self: *CPU) void {
        self.PC = self.bus.read(RESET_VECTOR) | (@as(u16, self.bus.read(RESET_VECTOR + 1)) << 8);
    }

    pub fn get_status_flag(self: CPU, flag: StatusFlag) u1 {
        return @intCast((self.status >> @intFromEnum(flag)) & 1);
    }

    pub fn set_status_flag(self: *CPU, flag: StatusFlag, val: u1) void {
        const bit_index = @intFromEnum(flag);
        self.status &= ~(@as(u8, 1) << bit_index); // clear bit
        self.status |= (@as(u8, val) << bit_index);
    }

    pub fn toggle_status_flag(self: *CPU, flag: StatusFlag) void {
        const bit_index = @intFromEnum(flag);
        self.status ^= (@as(u8, 1) << bit_index);
    }

    pub fn clock_tick(self: *CPU) void {
        std.debug.print("Clock Tick!\n", .{});
        _ = self;
    }

    fn fetch_opcode(self: CPU) u8 {
        return self.bus.read(self.PC);
    }

    pub fn print_state(self: CPU) void {
        std.debug.print("\n----------------------------------------------------", .{});
        std.debug.print("\nCPU STATE:", .{});

        std.debug.print("\nPC: {b:0>16}", .{self.PC});
        std.debug.print("    {x:0>4}", .{self.PC});

        std.debug.print("\nSP:         {b:0>8}", .{self.SP});
        std.debug.print("    {x:0>4}", .{self.SP});

        std.debug.print("\nP:          {b:0>8}", .{self.status});
        std.debug.print("    {x:0>4}", .{self.status});

        std.debug.print("\nA:          {b:0>8}", .{self.A});
        std.debug.print("    {x:0>4}", .{self.A});

        std.debug.print("\nX:          {b:0>8}", .{self.X});
        std.debug.print("    {x:0>4}", .{self.X});

        std.debug.print("\nY:          {b:0>8}", .{self.Y});
        std.debug.print("    {x:0>4}", .{self.Y});

        std.debug.print("\n----------------------------------------------------\n", .{});
    }
};

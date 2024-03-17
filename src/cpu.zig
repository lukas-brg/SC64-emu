
const std = @import("std");
const Bus = @import("bus.zig").Bus;

const decode_opcode = @import("opcodes.zig").decode_opcode;

const RESET_VECTOR = 0xFFFC;
const STACK_BASE_POINTER: u16 = 0x100;

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
    /// Implementation of the 6502 microprocessor
    PC: u16,
    SP: u8,
    status: u8,
    A: u8,
    X: u8,
    Y: u8,
    bus: *Bus,
    cycle_count: u32 = 0,

    pub fn init(bus: *Bus) CPU {
        const cpu = CPU{
            .PC = 0,
            .SP = 0xFF,
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

    fn get_status_bit(self: CPU, bit_index: u3) u1 {
        return @intCast((self.status >> bit_index) & 1);
    }

    pub fn get_status_flag(self: CPU, flag: StatusFlag) u1 {
        return self.get_status_bit(@intFromEnum(flag));
    }

    pub fn set_status_flag(self: *CPU, flag: StatusFlag, val: u1) void {
        const bit_index = @intFromEnum(flag);
        self.status &= ~(@as(u8, 1) << bit_index); // clear bit
        self.status |= (@as(u8, val) << bit_index); // set bit
    }

    pub fn toggle_status_flag(self: *CPU, flag: StatusFlag) void {
        const bit_index = @intFromEnum(flag);
        self.status ^= (@as(u8, 1) << bit_index);
    }


    pub fn pop(self: *CPU) u8 {
        self.SP += 1;
        return self.bus.read(STACK_BASE_POINTER + self.SP);
    }

    pub fn push(self: *CPU, val: u8) void {
        self.bus.write(STACK_BASE_POINTER + self.SP, val);
        self.SP -= 1;
    }

    fn fetch_opcode(self: CPU) u8 {
        return self.bus.read(self.PC);
    }

    pub fn clock_tick(self: *CPU) void {
        std.debug.print("Clock Tick!\n", .{});
        const opcode = self.fetch_opcode();
        const instruction = decode_opcode(opcode);

        instruction.print();

        self.cycle_count += 1;
     
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

        std.debug.print("\n\nSTATUS FLAGS:", .{});
        std.debug.print("\nC Z I D B V N", .{});
        std.debug.print("\n{} {} {} {} {} {} {} ", 
            .{ self.get_status_bit(0), 
                    self.get_status_bit(1), 
                    self.get_status_bit(2), 
                    self.get_status_bit(3), 
                    self.get_status_bit(4), 
                    self.get_status_bit(6), 
                    self.get_status_bit(7) 
                });

        std.debug.print("\n----------------------------------------------------\n", .{});
    }
};

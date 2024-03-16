const std = @import("std");

const MEM_SIZE: u16 = 0xFFFF;

pub const Bus = struct {
    dummy_memory: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),

    pub fn write(self: *Bus, addr: u16, val: u8) void {
        self.dummy_memory[addr] = val;
    }

    pub fn read(self: Bus, addr: u16) u8 {
        return self.dummy_memory[addr];
    }
};

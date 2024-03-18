const std = @import("std");

const MEM_SIZE: u17 = 0x10000;

pub const Bus = struct {
    dummy_memory: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),

    pub fn write(self: *Bus, addr: u16, val: u8) void {
        self.dummy_memory[addr] = val;
    }

    pub fn write_continous(self: *Bus, buffer: []const u8, offset: u16) void {
        _ = buffer;
        _ = offset;
        _ = self;
    }

    pub fn read(self: Bus, addr: u16) u8 {
        return self.dummy_memory[addr];
    }
};

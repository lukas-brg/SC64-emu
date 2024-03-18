const std = @import("std");

const MEM_SIZE: u17 = 0x10000;

pub const Bus = struct {
    memory: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),

    pub fn write(self: *Bus, addr: u16, val: u8) void {
        self.memory[addr] = val;
    }

    pub fn write_continous(self: *Bus, buffer: []const u8, offset: u16) void {
        if (buffer.len + offset > self.memory.len) {
            const errorMessage = std.fmt.allocPrint("Buffer is too large to fit in memory at offset {}.", .{offset});
            std.debug.panic(errorMessage);
        }
       
        @memcpy(
            self.memory[offset..].ptr,
            buffer.ptr
        );
    }

    

    pub fn read(self: Bus, addr: u16) u8 {
        return self.memory[addr];
    }
};

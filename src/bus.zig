const std = @import("std");

const MEM_SIZE: u17 = 0x10000;

pub const Bus = struct {
    memory: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),

    pub fn init() Bus {
        return .{};
    }

    pub fn write(self: *Bus, addr: u16, val: u8) void {
        self.memory[addr] = val;
    }


    pub fn write_continous(self: *Bus, buffer: []const u8, offset: u16) void {
        if (buffer.len + offset > self.memory.len) {
            std.debug.panic("Buffer is too large to fit in memory at offset {}.", .{offset});
        }
       
        @memcpy(
            self.memory[offset..].ptr,
            buffer
        );
    }

    pub fn read(self: Bus, addr: u16) u8 {
        return self.memory[addr];
    }


    pub fn print_mem(self: *Bus, start: u16, len: u16) void {
        std.debug.print("\nMEMORY:", .{});
        for (self.memory[start..start+len], 0..len) |byte, count| {
            const addr = count+start;
            if (count % 16 == 0) {
                std.debug.print("\n{x:0>4}:  ", .{addr});
            }
            else if (count % 8 == 0) {
                std.debug.print(" ", .{});
            }
            std.debug.print("{x:0>2} ", .{byte});
        }

        std.debug.print("\n\n", .{});
    }
};

const std = @import("std");
const bitutils = @import("cpu/bitutils.zig");

const MEM_SIZE: u17 = 0x10000;


pub const MemoryMap = enum {
    pub const screen_mem_start= 0x0400;
    pub const screen_mem_end = 0x07E7;

    pub const color_mem_start  = 0xD800;
    pub const color_mem_end = 0xDBE7;

    pub const character_rom_start = 0xD000;
    pub const io_ram_start = 0xD000;
    pub const character_rom_end = 0xDFFF;
    
    pub const kernal_rom_start = 0xE000;
    pub const kernal_rom_end = 0xFFFF;
    
    pub const basic_rom_start = 0xA000;
    pub const basic_rom_end = 0xBFFF;
    
    pub const bg_color = 0xD021;
    pub const text_color = 0x0286;
    pub const frame_color = 0xD020;
    
    pub const raster_line_reg = 0xD012;

    pub const processor_port = 1;
};

pub const MemoryLocation = struct {
    val_ptr: *u8,
    read_only: bool,
    control_bits: u3, // This is intended to help debugging
};

pub const Bus = struct {
    ram: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),
    
    mem_size: u17 = MEM_SIZE,

    character_rom: [MemoryMap.character_rom_end-MemoryMap.character_rom_start+1]u8 = std.mem.zeroes([MemoryMap.character_rom_end-MemoryMap.character_rom_start+1]u8),
    io_ram: [MemoryMap.character_rom_end-MemoryMap.character_rom_start+1]u8 = std.mem.zeroes([MemoryMap.character_rom_end-MemoryMap.character_rom_start+1]u8),
    
    basic_rom: [MemoryMap.basic_rom_end-MemoryMap.basic_rom_start+1]u8 = std.mem.zeroes([MemoryMap.basic_rom_end-MemoryMap.basic_rom_start+1]u8),
    
    kernal_rom: [MemoryMap.kernal_rom_end-MemoryMap.kernal_rom_start+1]u8 = std.mem.zeroes([MemoryMap.kernal_rom_end-MemoryMap.kernal_rom_start+1]u8),

    pub fn init() Bus {
        return .{};
    }

    
    pub fn write(self: *Bus, addr: u16, val: u8) void {
        const mem_location = self.access_mem_location(addr);
        if (!mem_location.read_only) {
            mem_location.val_ptr.* = val;
        }
        else {
            std.debug.print("Trying to write to rom {}, writing to ram instead", .{addr});
            self.ram[addr] = val;
        }
    }

    pub fn write_io_ram(self: *Bus, addr: u16, val: u8) void {
       const index = addr - MemoryMap.io_ram_start;
       self.io_ram[index] = val;
    }
    
    pub fn write_16(self: *Bus, addr: u16, val: u16) void {
        const bytes = bitutils.split_into_bytes(val);
        self.write(addr, bytes[0]);
        self.write(addr+1, bytes[1]);
    }

    pub fn read(self: *Bus, addr: u16) u8 {
        const mem_location = self.access_mem_location(addr);
        return mem_location.val_ptr.*;
    }

    pub fn read_16(self: *Bus, addr: u16) u16 {
        const low = self.read(addr);
        const high = self.read(addr+1);
        return bitutils.combine_bytes(low, high);
    }

    pub fn write_continous(self: *Bus, buffer: []const u8, offset: u16) void {
        if (buffer.len + offset > self.ram.len) {
            std.debug.panic("Buffer is too large to fit in memory at offset {}.", .{offset});
        }
        
        for (offset..offset+buffer.len, buffer) |addr, val| {
            self.write(@intCast(addr), val);
        }
    }
    

    pub fn print_mem(self: *Bus, start: u16, end: u17) void {
        std.debug.print("\nMEMORY:", .{});
        std.debug.assert(end > start);
        for (start..end, 0..end-start) | addr , count| {
            const byte = self.read(@intCast(addr));
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
    
    fn access_mem_location(self: *Bus, addr: u16) MemoryLocation {
        const banking_control_bits: u3 = @truncate(self.ram[MemoryMap.processor_port] & 7);
        const ram_control_bits: u2 = @truncate(banking_control_bits & 3);
        
        var val_ptr: *u8 = undefined;
        var read_only = false;
        
        switch (addr) {
            MemoryMap.basic_rom_start...MemoryMap.basic_rom_end => {
                switch (ram_control_bits) {
                    0b11=> {
                        val_ptr = &self.basic_rom[addr-MemoryMap.basic_rom_start];
                        read_only = true;
                    },
                    else => {
                        val_ptr = &self.ram[addr];
                    }
                }
            },
            MemoryMap.kernal_rom_start...MemoryMap.kernal_rom_end => {
                switch (bitutils.get_bit_at(ram_control_bits, 1)) {
                    1=> {
                        val_ptr = &self.kernal_rom[addr-MemoryMap.kernal_rom_start];
                        read_only = true;
                    },
                    0 => {
                        val_ptr = &self.ram[addr];
                    }
                }
            },
            MemoryMap.character_rom_start...MemoryMap.character_rom_end => {
                switch (ram_control_bits) {
                    0 => {
                        val_ptr = &self.ram[addr];
                    },
                    else => {
                        switch (bitutils.get_bit_at(banking_control_bits, 2)) {
                            0 => {
                                val_ptr = &self.character_rom[addr-MemoryMap.character_rom_start];
                                read_only = true;
                            },
                            1 => {
                                val_ptr = &self.io_ram[addr-MemoryMap.character_rom_start];
                            }
                        }
                    }
                }
            },
            else => {
                val_ptr = &(self.ram[addr]);
            }
        }

        return .{.val_ptr = @constCast(val_ptr),
                 .read_only = read_only,
                 .control_bits = banking_control_bits};
        }

};

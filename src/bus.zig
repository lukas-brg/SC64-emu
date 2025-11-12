const std = @import("std");
const bitutils = @import("cpu/bitutils.zig");
const cia = @import("cia.zig");
const log_bus = std.log.scoped(.bus);
const MemoryMap = @import("memory_map.zig");

const MEM_SIZE: u17 = 0x10000;

var bus_s = std.Thread.Semaphore{};
var bus_m = std.Thread.Mutex{};


pub const MemoryLocation = struct {
    val_ptr: *u8,
    read_only: bool,
    control_bits: u3, // This is intended to help debugging,
   
};

pub const Bus = struct {
    ram: [MEM_SIZE]u8 = std.mem.zeroes([MEM_SIZE]u8),
    mutex: std.Thread.Mutex = .{},
    ram_mutex: std.Thread.Mutex = .{},
    io_ram_mutex: std.Thread.Mutex = .{},
    cia1: *cia.CiaI,
    mem_size: u17 = MEM_SIZE,

    character_rom: [MemoryMap.character_rom_end - MemoryMap.character_rom_start + 1]u8 = std.mem.zeroes([MemoryMap.character_rom_end - MemoryMap.character_rom_start + 1]u8),
    io_ram: [MemoryMap.character_rom_end - MemoryMap.character_rom_start + 1]u8 = std.mem.zeroes([MemoryMap.character_rom_end - MemoryMap.character_rom_start + 1]u8),

    basic_rom: [MemoryMap.basic_rom_end - MemoryMap.basic_rom_start + 1]u8 = std.mem.zeroes([MemoryMap.basic_rom_end - MemoryMap.basic_rom_start + 1]u8),

    kernal_rom: [MemoryMap.kernal_rom_end - MemoryMap.kernal_rom_start + 1]u8 = std.mem.zeroes([MemoryMap.kernal_rom_end - MemoryMap.kernal_rom_start + 1]u8),

    enable_bank_switching: bool = true,

    pub fn init(cia1: *cia.CiaI) Bus {
        return .{.cia1= cia1};
    }

    pub fn write(self: *Bus, addr: u16, val: u8) void {
        //self.mutex.lock();
       // defer self.mutex.unlock();
       
        if (addr >= MemoryMap.cia1_start and addr <= MemoryMap.cia1_end) {
            const banking_control_bits: u3 = @truncate(self.ram[MemoryMap.processor_port]);
            if (bitutils.getBitAt(banking_control_bits, 2) == 1) {
                self.cia1.writeCiaRam(addr, val);
                return;
            }
        }
        
      
    
        const mem_location = self.accessMemLocation(addr);
        if (addr >= MemoryMap.character_rom_start and addr <= MemoryMap.character_rom_end and mem_location.read_only) {
            log_bus.err("Writing to character rom at {X:0>4}\n", .{addr});
        }

        if (addr == MemoryMap.processor_port and ((val & 7) != (self.ram[addr] & 7))) {
            const new_control_bits: u3 = @truncate(val);
            log_bus.debug("Bank switch. Control bits changed from [{b:0>3}] to [{b:0>3}]", .{ mem_location.control_bits, new_control_bits });
        }

    
        if (!mem_location.read_only) {
            mem_location.val_ptr.* = val;
        } else {
            log_bus.debug("Trying to write to rom at ({X}), writing to ram instead. Control bits: [{b:0>3}]", .{ addr, mem_location.control_bits });
            self.ram[addr] = val;
        }
        
    }

    pub fn read(self: *Bus, addr: u16) u8 {
        if (addr >= MemoryMap.cia1_start and addr <= MemoryMap.cia1_end) {
            const banking_control_bits: u3 = @truncate(self.ram[MemoryMap.processor_port]);
            if (bitutils.getBitAt(banking_control_bits, 2) == 1) {
                return self.cia1.readCiaRam(addr);
            }
        }

        const mem_location = self.accessMemLocation(addr);
        return mem_location.val_ptr.*;
        
    }

    pub fn writeIORam(self: *Bus, addr: u16, val: u8) void {
        const index = addr - comptime MemoryMap.io_ram_start;
      //  self.io_ram_mutex.lock();
        // self.cia1.write_io_ram(addr, val);
        self.io_ram[index] = val;
      //  self.io_ram_mutex.unlock();
    }

    pub fn readIORam(self: *Bus, addr: u16) u8 {
        const index = addr - comptime MemoryMap.io_ram_start;
     //   self.io_ram_mutex.lock();
        const val = self.io_ram[index];
     //   self.io_ram_mutex.unlock();
        // return self.cia1.read_io_ram(addr);
        return val;
    }

    pub fn aquireIoRam(self: *Bus) []u8 {
       self.io_ram_mutex.lock();
        return self.io_ram;
    }

    pub fn writeRam(self: *Bus, addr: u16, val: u8) void {
      //  self.ram_mutex.lock();
        self.ram[addr] = val;
     //   self.ram_mutex.unlock();
    }

    pub fn readRam(self: *Bus, addr: u16) u8 {
      //  self.ram_mutex.lock();
        const val = self.ram[addr];
      //  self.ram_mutex.unlock();
        return val;
    }

    pub fn aquireRam(self: *Bus) []u8 {
        self.ram_mutex.lock();
        return self.ram;
    }

    pub fn write16(self: *Bus, addr: u16, val: u16) void {
        //if (addr > MEM_SIZE - 2) std.debug.panic("Trying to write out of bounds at {X:0>4}", .{addr});
        // const mem_location = self.access_mem_location(addr);
        // const ptr16: *u16 = @ptrCast(@alignCast(mem_location.val_ptr));
        // ptr16.* = val;
        
        const bytes = bitutils.splitIntoBytes(val);
        self.write(addr, bytes[0]);
        self.write(addr + 1, bytes[1]);
    }



    pub fn read16(self: *Bus, addr: u16) u16 {
        // if (addr > MEM_SIZE - 2) std.debug.panic("Trying to write out of bounds at {X:0>4}", .{addr});
        // const mem_location = self.access_mem_location(addr);
        // std.log.debug("addr {X:0>4}", .{addr});
        // const ptr16: *u16 = @ptrCast(@alignCast(mem_location.val_ptr));
        // return ptr16.*; 
        //if (addr > MEM_SIZE - 2) std.debug.panic("Trying to read from out of bounds at {X:0>4}", .{addr});
        const low = self.read(addr);
        const high = self.read(addr + 1);
        return bitutils.combineBytes(low, high);
    }

    pub fn writeContinuous(self: *Bus, buffer: []const u8, offset: u16) void {
        if (buffer.len + offset > self.ram.len) {
            std.debug.panic("Buffer is too large to fit in memory at offset {X}.", .{offset});
        }

        for (offset..offset + buffer.len, buffer) |addr, val| {
            self.write(@intCast(addr), val);
        }
    }

    pub fn printMem(self: *Bus, start: u16, end: u17) void {
        std.debug.print("\nMEMORY:", .{});
        std.debug.assert(end >= start);
        for (start..end, 0..end - start) |addr, count| {
            const byte = self.read(@intCast(addr));
            if (count % 16 == 0) {
                std.debug.print("\n{x:0>4}:  ", .{addr});
            } else if (count % 8 == 0) {
                std.debug.print(" ", .{});
            }
            std.debug.print("{x:0>2} ", .{byte});
        }

        std.debug.print("\n\n", .{});
    }

    fn accessMemLocation(self: *Bus, addr: u16) MemoryLocation {
        const banking_control_bits: u3 = @truncate(self.ram[MemoryMap.processor_port]);
        if (!self.enable_bank_switching) {
            return .{
                .val_ptr = @constCast(&self.ram[addr]),
                .read_only = false,
                .control_bits = banking_control_bits,
            };
        }

        const ram_control_bits: u2 = @truncate(banking_control_bits);

        var val_ptr: *u8 = undefined;
        var read_only = false;

        switch (addr) {
            MemoryMap.basic_rom_start...MemoryMap.basic_rom_end => {
                switch (ram_control_bits) {
                    0b11 => {
                        val_ptr = &self.basic_rom[addr - MemoryMap.basic_rom_start];
                        read_only = true;
                    },
                    else => {
                        val_ptr = &self.ram[addr];
                    },
                }
            },
            MemoryMap.kernal_rom_start...MemoryMap.kernal_rom_end => {
                switch (bitutils.getBitAt(ram_control_bits, 1)) {
                    1 => {
                        val_ptr = &self.kernal_rom[addr - MemoryMap.kernal_rom_start];
                        read_only = true;
                    },
                    0 => {
                        val_ptr = &self.ram[addr];
                    },
                }
            },
            MemoryMap.character_rom_start...MemoryMap.character_rom_end => {
                switch (ram_control_bits) {
                    0 => {
                        val_ptr = &self.ram[addr];
                    },
                    else => {
                        switch (bitutils.getBitAt(banking_control_bits, 2)) {
                            0 => {
                                val_ptr = &self.character_rom[addr - MemoryMap.character_rom_start];
                                read_only = true;
                            },
                            1 => {
                                switch (addr) {

                                    MemoryMap.cia1_mirrored_start...MemoryMap.cia1_end => {
                                        const offset = (addr - MemoryMap.cia1_mirrored_start) % 16;
                                        const io_idx = offset + comptime (MemoryMap.cia1_start - MemoryMap.io_ram_start);
                                        val_ptr = &self.io_ram[io_idx];
                                    },
                                    else => val_ptr = &self.io_ram[addr - MemoryMap.character_rom_start]                      
                                }
                            },
                        }
                    },
                }
            },
            else => {
                val_ptr = &(self.ram[addr]);
            },
        }

        return .{
            .val_ptr = @constCast(val_ptr),
            .read_only = read_only,
            .control_bits = banking_control_bits,
        };
    }
};


pub const _Bus = struct {
    read: fn(addr: u16) u8,
    write: fn(addr: u16, val: u8) void,
    read_16: fn(addr: u16) u16,
    write_16: fn(addr: u16, val: u8) void,

};
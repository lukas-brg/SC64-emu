const builtin = @import("builtin");
const std = @import("std");
const kb = @import("keyboard.zig");
const bitutils = @import("cpu/bitutils.zig");
// const b = @import("bus.zig");
const c = @import("cpu/cpu.zig");
// const Bus = b.Bus;


pub const CiaIAddresses = enum {
    pub const port_a       = 0xDC00;
    pub const port_b       = 0xDC01;
    pub const ddra         = 0xDC02;
    pub const ddrb         = 0xDC04;
    pub const timer_a_lo   = 0xDC04;
    pub const timer_a_hi   = 0xDC05;
    pub const timer_b_lo   = 0xDC06;
    pub const timer_b_hi   = 0xDC07;
    pub const rtc_tenth    = 0xDC08;
    pub const rtc_sec      = 0xDC09;
    pub const rtc_min      = 0xDC0A;
    pub const rtc_hr       = 0xDC0B;
    pub const serial_shift = 0xDC0C;
    pub const icr          = 0xDC0D;
    pub const timer_a_ctrl = 0xDC0E;
    pub const timer_b_ctrl = 0xDC0F;
};

pub const Timer = union {
    u16_value: u16,
    bytes: packed struct(u16) {
        lo: u8,
        hi: u8,
    },
};

pub const CiaI = struct {
    cpu: *c.CPU,
    keyboard: *kb.Keyboard, // later replace with generic input device
    port_a: u8 = 0xFF,
    port_b: u8 = 0xFF,
    ddr_a: u8 = 0,
    ddr_b: u8 = 0,
    
    pub fn init(cpu: *c.CPU, keyboard: *kb.Keyboard) CiaI {
        const cia1: CiaI = .{
            .cpu         = cpu,
            .keyboard = keyboard,
        };
       
        return cia1;
    }



    pub fn writeCiaRam(self: *CiaI, addr: u16, value: u8) void {
        switch (addr) {
            CiaIAddresses.ddra => {
                self.ddr_a = value;
            },
            CiaIAddresses.ddrb => {
                self.ddr_b = value;
            },
            CiaIAddresses.port_a => {
                self.port_a = (self.port_a & ~self.ddr_a) | (value & self.ddr_a);
                // self.port_a = value;
                
            },
            CiaIAddresses.port_b => {
                self.port_b = (self.port_b & ~self.ddr_b) | (value & self.ddr_b);
            },
            else => {}
        }
        
    }

    
    pub fn readCiaRam(self: *CiaI, addr: u16) u8 {
        switch (addr) {
            CiaIAddresses.port_a => {
                return (self.port_a & ~self.ddr_a) | (self.port_a & self.ddr_a);
            },
            CiaIAddresses.port_b => {
                var result: u8 = 0xFF; 
                var a: u8 = 0xFF;
                for (0..8) |_col| {
                    const col: u3 = @truncate(_col);
                    if ((self.port_a & (@as(u8, 1) << col)) == 0) {
                        const kb_entry = self.keyboard.keyboard_matrix[col];
                        result &= kb_entry;
                        a = kb_entry;
                    }
                }
                const retval = (result & ~self.ddr_b) | (self.port_b & self.ddr_b);
                _ = retval;
                return result;
            },
            CiaIAddresses.ddra => return self.ddr_a,
            CiaIAddresses.ddrb => return self.ddr_b,
            else => return 0,
         }


    }


    pub fn setKeyDown(self: *CiaI, row: u3, col: u3) void {
        self.keyboard_matrix[col] &= ~(@as(u8, 1) << row);
    }

    pub fn setKeyUp(self: *CiaI, row: u3, col: u3) void {
        self.keyboard_matrix[col] |= @truncate(@as(u8, 1) << row);
    }

};



const CiaII = enum {

};
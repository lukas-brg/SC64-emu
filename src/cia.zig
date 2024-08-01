const builtin = @import("builtin");
const std = @import("std");

const bitutils = @import("cpu/bitutils.zig");
const b = @import("bus.zig");
const c = @import("cpu/cpu.zig");
const Bus = b.Bus;


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

pub const CiaI = packed struct {
    port_a: *u8,
    port_b: *u8,
    ddra: *u8, 
    ddrb: *u8, 
    timer_a_lo: *u8,
    timer_a_hi: *u8,
    timer_b_lo: *u8,
    timer_b_hi: *u8,
    rtc_tenth: *u8,
    rtc_sec: *u8, 
    rtc_min: *u8,
    rtc_hr: *u8,
    serial_shift: *u8,
    icr: *u8,
    timer_a_ctrl: *u8,
    timer_b_ctrl: *u8,
    bus: *Bus,
    cpu: *c.CPU,
    
    
    pub fn init(bus: *Bus, cpu: *c.CPU) CiaI {
        const cia1: CiaI = .{
            .port_a       = get_ioram_ptr(bus, CiaIAddresses.port_a),
            .port_b       = get_ioram_ptr(bus, CiaIAddresses.port_b),
            .ddra         = get_ioram_ptr(bus, CiaIAddresses.ddra),
            .ddrb         = get_ioram_ptr(bus, CiaIAddresses.ddrb),
            .timer_a_lo   = get_ioram_ptr(bus, CiaIAddresses.timer_a_lo),
            .timer_b_lo   = get_ioram_ptr(bus, CiaIAddresses.timer_b_lo),
            .timer_a_hi   = get_ioram_ptr(bus, CiaIAddresses.timer_a_hi),
            .timer_b_hi   = get_ioram_ptr(bus, CiaIAddresses.timer_b_hi),
            .rtc_tenth    = get_ioram_ptr(bus, CiaIAddresses.rtc_tenth),
            .rtc_sec      = get_ioram_ptr(bus, CiaIAddresses.rtc_sec),
            .rtc_min      = get_ioram_ptr(bus, CiaIAddresses.rtc_min),
            .rtc_hr       = get_ioram_ptr(bus, CiaIAddresses.rtc_hr),
            .serial_shift = get_ioram_ptr(bus, CiaIAddresses.serial_shift),
            .icr          = get_ioram_ptr(bus, CiaIAddresses.icr),
            .timer_a_ctrl = get_ioram_ptr(bus, CiaIAddresses.timer_a_ctrl),
            .timer_b_ctrl = get_ioram_ptr(bus, CiaIAddresses.timer_b_ctrl),
            .bus         = bus,
            .cpu         = cpu,
        };
       
        return cia1;
    }

    pub fn set_register_atomic(self: *CiaI, ptr: *u8, val: u8) void {
        _ = self;
        @atomicStore(u8, ptr, val, .release);
    }
    
    pub fn get_register_atomic(self: *CiaI, ptr: *u8) u8 {
        _ = self;
        return @atomicLoad(u8, ptr, .acquire);
    }

    fn get_ioram_ptr(bus: *Bus, addr: u16) *u8 {
        return &bus.io_ram[addr-b.MemoryMap.io_ram_start];
    }

    pub fn read_timer_a(self: *CiaI) u16 {
        if (comptime builtin.cpu.arch.endian() == .little ) {
            const u16ptr: *u16 = @ptrCast(@alignCast(self.timer_a_lo));
            return u16ptr.*;
        } else {
            return bitutils.combine_bytes(self.timer_a_lo.*, self.timer_a_hi.*);
        }
    }

    pub fn read_timer_b(self: *CiaI) u16 {
        if (comptime builtin.cpu.arch.endian() == .little ) {
            const u16ptr: *u16 = @ptrCast(@alignCast(self.timer_b_lo));
            return u16ptr.*;
        } else {
            return bitutils.combine_bytes(self.timer_b_lo.*, self.timer_b_hi.*);
        }
    }


    pub fn write_timer_a(self: *CiaI, value: u16) void {
        if (comptime builtin.cpu.arch.endian() == .little ) {
            const u16ptr: *u16 = @ptrCast(@alignCast(self.timer_a_lo));
            u16ptr.* = value;
        } else {
            const bytes = bitutils.split_into_bytes(value);
            self.timer_a_lo.* = bytes[0];
            self.timer_a_hi.* = bytes[1];
        }
    }
    
    pub fn write_timer_b(self: *CiaI, value: u16) void {
        if (comptime builtin.cpu.arch.endian() == .little ) {
            const u16ptr: *u16 = @ptrCast(@alignCast(self.timer_b_lo));
            u16ptr.* = value;
        } else {
            const bytes = bitutils.split_into_bytes(value);
            self.timer_b_lo.* = bytes[0];
            self.timer_b_hi.* = bytes[1];
        }
    }

    pub fn dec_timer_a(self: *CiaI) void {
        var val = self.read_timer_a();
        val -%= 1;
        if (val == 0) {
            //self.cpu.irq();
        }
        self.write_timer_a(val);
    }

    pub fn dec_timer_b (self: *CiaI) void {
        var val = self.read_timer_b();
        val -%= 1;
        if (val == 0) {
            //self.cpu.irq();
        }
        self.write_timer_b(val);
    }

    pub fn dec_timers (self: *CiaI) void {
        self.dec_timer_a();
        self.dec_timer_b();
    }

};



const CiaII = enum {

};
const b = @import("bus.zig");
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


pub const CiaI = struct {
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
    timer_a_ctrl: *u8,
    timer_b_ctrl: *u8,
    _bus: *Bus,

    fn get_ioram_ptr(bus: *Bus, addr: u16) *u8 {
        return &bus.io_ram[addr-b.MemoryMap.io_ram_start];
    }

    pub fn init(bus: *Bus) CiaI {
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
            .timer_a_ctrl = get_ioram_ptr(bus, CiaIAddresses.timer_a_ctrl),
            .timer_b_ctrl = get_ioram_ptr(bus, CiaIAddresses.timer_b_ctrl),
            ._bus = bus,
        };

        return cia1;
    }
};


const CiaII = enum {

};
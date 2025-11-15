const std = @import("std");

pub const PrecisionClock = struct {
    period_ns: u64,
    current_start: i128 = 0,
    next_target: i128 = 0,


    pub fn initNs(period_ns: u64) PrecisionClock {
        const clock = PrecisionClock{
            .period_ns = period_ns,
            .current_start = 0,
        };
        return clock;
    }

    pub fn initHz(freq_hz: u64) PrecisionClock {
        const period_ns: u64 = @intCast(1_000_000_000 / freq_hz);
        return PrecisionClock.initNs(period_ns);
    }


    pub inline fn start(self: *PrecisionClock) void {
        self.current_start = std.time.nanoTimestamp();
        self.next_target = self.current_start + self.period_ns;
    }

    pub inline fn end(self: *PrecisionClock) void {
        while((std.time.nanoTimestamp()) < self.next_target) {}
    }
};
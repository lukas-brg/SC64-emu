const std = @import("std");

pub const PrecisionClock = struct {
    target_duration_ns: u64,
    target_duration_ns_adjusted: u64 = 0,
    start_time: i128 = 0,
    next_target_time: i128 = 0,


    pub fn init(target_duration_ns: u64) PrecisionClock {
        const clock = PrecisionClock{
            .target_duration_ns = target_duration_ns,
            .start_time = 0,
        };
        // clock.calibrate();
        return clock;
    }

    fn calibrate(self: *PrecisionClock) void {
        self.target_duration_ns_adjusted = self.target_duration_ns;
        const cycles = @max(30, 50000000 / self.target_duration_ns);
        const start_t = std.time.nanoTimestamp();
        for (0..cycles) |_| {
            self.start();
            for (0..10) |_| {}
            self.end();
        }
        const end_t = std.time.nanoTimestamp();
        const elapsed_total: u64 = @intCast(end_t - start_t);
        const elapsed_per_cycle = elapsed_total / cycles;
        const overhead = elapsed_per_cycle - self.target_duration_ns;
        self.target_duration_ns_adjusted = self.target_duration_ns - overhead;
    }

    pub inline fn start(self: *PrecisionClock) void {
        self.start_time = std.time.nanoTimestamp();
        self.next_target_time = self.start_time + self.target_duration_ns;
    }

    pub inline fn end(self: *PrecisionClock) void {
        // const elapsed = std.time.nanoTimestamp() - self.start_time;

        while((std.time.nanoTimestamp()) < self.next_target_time) {}

        // if (elapsed < self.target_duration_ns) {
        //     while ((std.time.nanoTimestamp() - self.start_time) < self.target_duration_ns) {}
        // } 
        // else {
        //     std.debug.print("{} exceeded clock period\n", .{self.start_time});
        // }
    }
};
const std = @import("std");
const c = @import("cpu.zig");
const Bus = @import("bus.zig").Bus;

pub fn main() !void {
    std.debug.print("Hello, World!\n", .{});

    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    const flag = cpu.get_status_flag(c.StatusFlag.DECIMAL);

    std.debug.print("Status flag {}", .{flag});
    cpu.print_state();
    bus.write(0, 255);

    cpu.clock_tick();
    std.debug.print("{}\n", .{bus.read(0)});
}

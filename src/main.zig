const std = @import("std");
const c = @import("cpu.zig");
const Bus = @import("bus.zig").Bus;

pub fn main() !void {
    var bus = Bus{};

    var cpu = c.CPU.init(&bus);
    test_init_reset_vector(&bus);
    cpu.reset();
    cpu.set_status_flag(c.StatusFlag.BREAK, 1);
    cpu.clock_tick();
    cpu.print_state();
}

fn test_init_reset_vector(bus: *Bus) void {
    // Reset vector to 0x2010
    bus.write(0xfffc, 0x10);
    bus.write(0xfffd, 0x20);
}

test "loading reset vector into pc" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    test_init_reset_vector(&bus);
    cpu.reset();

    assert(cpu.PC == 0x2010);
}

test "set status flag" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();

    cpu.set_status_flag(c.StatusFlag.BREAK, 1);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.set_status_flag(c.StatusFlag.BREAK, 0);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);
}

test "stack operations" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();
    cpu.push(0x4D);
    assert(cpu.pop() == 0x4D);
}

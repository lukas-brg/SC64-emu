
const Bus = @import("bus.zig").Bus;
const MemoryMap = @import("memory_map.zig");
const hooks = @import("hooks.zig");
const charset = @import("charset.zig");
const std = @import("std");
const machine_state = @import("machine_state.zig");
const QUEUE_CAPACITY = 100;

var queue_buffer: [QUEUE_CAPACITY]u8 = undefined;
var head: usize = 0;
var tail: usize = 0;
var queue_pending: usize = 0;

var kb_buf: []u8 = undefined;
var kb_buf_len: usize = 0;

var _bus: *Bus = undefined;


fn flush(t: hooks.HookTrigger) void {
    var i: usize = 0;
    _ = t;
    while (dequeue()) |char| {
        if (i < kb_buf.len) {

            std.debug.print("flush {x:0>2} at {}\n", .{char, machine_state.current_cycle});
            kb_buf[i] = char;
            _bus.write(MemoryMap.kb_buf_len, 10);
            i += 1;
        } else {
            break;
        }
    }
}

fn dequeue() ?u8 {
    if (head == tail) return null;
    const ret = queue_buffer[head];
    head += 1;
    queue_pending -= 1;
    head %= QUEUE_CAPACITY;
    return ret;
}


pub fn peek() ?u8 {
    if (head == tail) return null;
    const ret = queue_buffer[head];
    return ret;
}

pub fn insertChar(asciiChar: u8) void {
    const petscii = charset.asciiToPetscii(asciiChar) orelse ' ';
    queue_buffer[tail] = petscii;
    tail += 1;
    tail %= QUEUE_CAPACITY;
    queue_pending += 1;
    hooks.registerHook(.{.trigger = .{ .in_n_cycles = 10000 }, .callback = flush}) catch {};
    std.debug.print("hook registered  char {c} at cycle {}\n", .{asciiChar, machine_state.current_cycle});
     
}

pub fn insertStr(asciiStr: []const u8) void {
    for (asciiStr) |c| {
        insertChar(c);
    }
}

pub fn init(keyboard_buffer: []u8, b: *Bus) void {
    kb_buf = keyboard_buffer;
    _bus = b;
}
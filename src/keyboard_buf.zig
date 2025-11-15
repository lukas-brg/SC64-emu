
const Bus = @import("bus.zig").Bus;
const MemoryMap = @import("memory_map.zig");
const hooks = @import("hooks.zig");
const charset = @import("charset.zig");

const QUEUE_CAPACITY = 100;

var queue_buffer: [QUEUE_CAPACITY]u8 = undefined;
var head: usize = 0;
var tail: usize = 0;
var queue_pending: usize = 0;

var kb_buf: []u8 = undefined;
var kb_buf_len: usize = 0;

var _bus: *Bus = undefined;


fn flush() void {
}

pub fn dequeue() ?u8 {
    if (head == tail) return null;
    const ret = queue_buffer[head];
    head += 1;
    head %= QUEUE_CAPACITY;
    return ret;
}


pub fn peek() ?u8 {
    if (head == tail) return null;
    const ret = queue_buffer[head];
    return ret;
}

pub fn feedChar(char: u8) void {
    const petscii = charset.asciiToPetscii(char);
    queue_buffer[tail] = petscii;
    tail += 1;
    tail %= QUEUE_CAPACITY;
    queue_pending += 1;    
}

pub fn feedStr(str: []const u8) void {
    for (str) |c| {
        feedChar(c);
    }
}

pub fn init(keyboard_buffer: []u8) void {
    kb_buf = keyboard_buffer;
}
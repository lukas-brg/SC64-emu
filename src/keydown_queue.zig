const keymap = @import("keymap.zig");
const KeyDownEvent = @import("keydown_event.zig").KeyDownEvent;
// const keydown_event = @import("keydown_event.zig");

const CAPACITY = 100;

var buffer: [CAPACITY]KeyDownEvent = undefined;
var head: usize = 0;
var tail: usize = 0;



pub fn enqueue(event: KeyDownEvent) void {
    buffer[tail] = event;
    tail += 1;
    tail %= CAPACITY;
    
}

pub fn dequeue() ?KeyDownEvent {
    if (head == tail) return null;
    const ret = buffer[head];
    head += 1;
    head %= CAPACITY;
    return ret;
}


pub fn peek() ?KeyDownEvent {
    if (head == tail) return null;
    const ret = buffer[head];
    return ret;
}
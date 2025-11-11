const keymap = @import("keymap.zig");
const keydown_event = @import("keydown_event.zig");
const KeyDownEvent = keydown_event.KeyDownEvent;
var list: [100]KeyDownEvent = undefined;
var head: isize = -1;


pub fn enqueue(event: KeyDownEvent) void {
    head += 1;
    list[@as(usize, @intCast(head))] = event;
}

pub fn dequeue() ?KeyDownEvent {
    if (head < 0) return null;
    const ret = list[@as(usize, @intCast(head))];
    head -= 1;
    return ret;
}


pub fn peek() ?KeyDownEvent {
    if (head < 0) return null;
    const ret = list[@as(usize, @intCast(head))];
    return ret;
}
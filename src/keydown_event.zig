const keymap = @import("keymap.zig");

pub const KeyDownEvent = struct {
    keycode: keymap.C64KeyCode,
    at_cycle: usize,
};
const std = @import("std");

const graphics = @import("graphics.zig");
const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const bus = @import("bus.zig");

const log_io = std.log.scoped(.io);
const raylib = graphics.raylib;

const keymap = @import("keymap.zig");
const runtime_info = @import("runtime_info.zig");

const keyevent_queue = @import("keyevent_queue.zig");
const paste_queue = @import("paste_queue.zig");

const KeyDownEvent = @import("keydown_event.zig").KeyDownEvent;

pub const Keyboard = struct {
    // Maybe make a interface for the cia1 connected device and let this be one implementation of it.
    keyboard_matrix: [8]u8,
    last_paste_at_cycle: usize = 0,
    paste_last_insert_at: usize = 0,

    pub fn init() Keyboard {
        return Keyboard{
            .keyboard_matrix = [8]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        };
    }

    pub fn getClipboardText() ?[]const u8 {
        const text = raylib.GetClipboardText();
        if (text == null) return null;
        return text;
    }

    pub fn setKeyDown(self: *Keyboard, row: u3, col: u3) void {
        self.keyboard_matrix[col] &= ~(@as(u8, 1) << row);
    }

    pub fn setKeyUp(self: *Keyboard, row: u3, col: u3) void {
        self.keyboard_matrix[col] |= @as(u8, 1) << row;
    }

    pub fn update(self: *Keyboard) void {
        while (true) {
            if (keyevent_queue.peek()) |event| {
                if (runtime_info.current_cycle - event.at_cycle >= 10000) {
                    _ = keyevent_queue.dequeue();
                    const key = keymap.lookupC64PhysicalKey(event.keycode);
                    std.debug.print("releasing key {s} at {}\n", .{ @tagName(event.keycode), runtime_info.current_cycle });
                    self.setKeyUp(key.row, key.col);
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        if (raylib.IsKeyDown(raylib.KEY_LEFT_CONTROL) and raylib.IsKeyDown(raylib.KEY_V) and runtime_info.current_cycle - self.last_paste_at_cycle >= 800000) {
            const clip: [*c]const u8 = @ptrCast(raylib.GetClipboardText());
            if (clip != null) {
                const len = std.mem.len(clip);
                const slice = clip[0..len];
                for (slice) |_char| {
                    var char = _char;
                    if (char >= 'a' and char <= 'z') {
                        char -= 32;
                    }
                    // std.debug.print("{c}\n'", .{char});
                    const keymapping = keymap.lookupC64Char(@intCast(char)) orelse continue;
                    for (keymapping.keys, 0..keymapping.keys.len) |keycode, _| {
                        // const key = keymap.lookup_c64_physical_key(keycode);
                        // self.set_key_down(key.row, key.col);
                        paste_queue.enqueue(.{ .keycode = keycode, .at_cycle = runtime_info.current_cycle });
                    }
                }
                self.last_paste_at_cycle = runtime_info.current_cycle;
                self.paste_last_insert_at = runtime_info.current_cycle;
                return;
            }
        }

        if (paste_queue.peek()) |event| {
            if (runtime_info.current_cycle - self.paste_last_insert_at >= 14400) {
                const key = keymap.lookupC64PhysicalKey(event.keycode);
                self.setKeyDown(key.row, key.col);
                std.debug.print("paste: {s} at {}\n", .{ @tagName(event.keycode), runtime_info.current_cycle });
                _ = paste_queue.dequeue();
                self.paste_last_insert_at = runtime_info.current_cycle;
                keyevent_queue.enqueue(.{ .keycode = event.keycode, .at_cycle = runtime_info.current_cycle });
                return;
            }
        }

        // Handle printable keys/chars in a host layout agnostic way
        while (true) {
            var char: c_int = raylib.GetCharPressed();
            if (char == 0) break;
            // Ensure uppercase for alphabetic chars
            if (char >= 'a' and char <= 'z') {
                char -= 32;
            }
            const keymapping = keymap.lookupC64Char(@intCast(char)) orelse continue;
            for (keymapping.keys) |keycode| {
                const key = keymap.lookupC64PhysicalKey(keycode);
                self.setKeyDown(key.row, key.col);
                keyevent_queue.enqueue(.{ .keycode = keycode, .at_cycle = runtime_info.current_cycle });
            }
        }

        // Handle control keys
        if (raylib.IsKeyDown(raylib.KEY_ENTER)) {
            const key = keymap.lookupC64PhysicalKey(.KEY_RETURN);
            self.setKeyDown(key.row, key.col);
        } else {
            const key = keymap.lookupC64PhysicalKey(.KEY_RETURN);
            self.setKeyUp(key.row, key.col);
        }

        if (raylib.IsKeyDown(raylib.KEY_BACKSPACE)) {
            const key = keymap.lookupC64PhysicalKey(.KEY_DELETE);
            self.setKeyDown(key.row, key.col);
        } else {
            const key = keymap.lookupC64PhysicalKey(.KEY_DELETE);
            self.setKeyUp(key.row, key.col);
        }

        if (raylib.IsKeyDown(raylib.KEY_LEFT)) {
            const key = keymap.lookupC64PhysicalKey(.KEY_ARROW_LEFT);
            self.setKeyDown(key.row, key.col);
        } else {
            const key = keymap.lookupC64PhysicalKey(.KEY_ARROW_LEFT);
            self.setKeyUp(key.row, key.col);
        }
    }
};

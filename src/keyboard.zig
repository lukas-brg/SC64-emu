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

    pub fn init() Keyboard {
        return Keyboard{
            .keyboard_matrix = [8]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        };
    }

    pub fn get_clipboard_text() ?[]const u8 {
        const text = raylib.GetClipboardText();
        if (text == null) return null;
        return text;
    }

    pub fn set_key_down(self: *Keyboard, row: u3, col: u3) void {
        self.keyboard_matrix[col] &= ~(@as(u8, 1) << row);
    }

    pub fn set_key_up(self: *Keyboard, row: u3, col: u3) void {
        self.keyboard_matrix[col] |= @as(u8, 1) << row;
    }

    pub fn select_col(self: *Keyboard, col: u3) u8 {
        return self.keyboard_matrix[col];
    }

    pub fn update(self: *Keyboard) void {
        var last_key_event: ?KeyDownEvent = null;
        while (true) {
            last_key_event = keyevent_queue.peek();

            if (last_key_event) |event| {
                if (runtime_info.current_cycle - event.at_cycle >= 10000) {
                    _ = keyevent_queue.dequeue();
                    const key = keymap.lookup_c64_physical_key(event.keycode);
                    self.set_key_up(key.row, key.col);
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        if (raylib.IsKeyDown(raylib.KEY_LEFT_CONTROL) and raylib.IsKeyDown(raylib.KEY_V) and runtime_info.current_cycle - self.last_paste_at_cycle >= 10000) {
            const clip: [*c]const u8 = @ptrCast(raylib.GetClipboardText());
            if (clip != null) {
                const len = std.mem.len(clip);
                const slice = clip[0..len];
                for (slice) |_char| {
                    var char = _char;
                    if (char >= 'a' and char <= 'z') {
                        char -= 32;
                    }
                    std.debug.print("{c}\n'", .{char});
                    const keymapping = keymap.lookup_c64_char(@intCast(char)) orelse continue;
                    for (keymapping.keys) |keycode| {
                        // const key = keymap.lookup_c64_physical_key(keycode);
                        // self.set_key_down(key.row, key.col);
                        paste_queue.enqueue(.{ .keycode = keycode, .at_cycle = runtime_info.current_cycle });
                    }
                }
            }
            self.last_paste_at_cycle = runtime_info.current_cycle;
        }

        if (paste_queue.dequeue()) |event| {
            const key = keymap.lookup_c64_physical_key(event.keycode);
            self.set_key_down(key.row, key.col);
            std.debug.print("paste: {s}\n", .{@tagName(event.keycode)});
            keyevent_queue.enqueue(.{ .keycode = event.keycode, .at_cycle = runtime_info.current_cycle });
            return;
        }

        // Handle printable keys/chars in a host layout agnostic way
        while (true) {
            var char: c_int = raylib.GetCharPressed();
            if (char == 0) break;
            // Ensure uppercase for alphabetic chars
            if (char >= 'a' and char <= 'z') {
                char -= 32;
            }
            const keymapping = keymap.lookup_c64_char(@intCast(char)) orelse continue;
            for (keymapping.keys) |keycode| {
                const key = keymap.lookup_c64_physical_key(keycode);
                self.set_key_down(key.row, key.col);
                keyevent_queue.enqueue(.{ .keycode = keycode, .at_cycle = runtime_info.current_cycle });
            }
        }

        // Handle control keys
        if (raylib.IsKeyDown(raylib.KEY_ENTER)) {
            const key = keymap.lookup_c64_physical_key(.KEY_RETURN);
            self.set_key_down(key.row, key.col);
        } else {
            const key = keymap.lookup_c64_physical_key(.KEY_RETURN);
            self.set_key_up(key.row, key.col);
        }

        if (raylib.IsKeyDown(raylib.KEY_BACKSPACE)) {
            const key = keymap.lookup_c64_physical_key(.KEY_DELETE);
            self.set_key_down(key.row, key.col);
        } else {
            const key = keymap.lookup_c64_physical_key(.KEY_DELETE);
            self.set_key_up(key.row, key.col);
        }

        if (raylib.IsKeyDown(raylib.KEY_LEFT)) {
            const key = keymap.lookup_c64_physical_key(.KEY_ARROW_LEFT);
            self.set_key_down(key.row, key.col);
        } else {
            const key = keymap.lookup_c64_physical_key(.KEY_ARROW_LEFT);
            self.set_key_up(key.row, key.col);
        }
    }
};

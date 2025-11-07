const std = @import("std");

const graphics = @import("graphics.zig");
const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const bus = @import("bus.zig");

const log_io = std.log.scoped(.io);
const raylib = graphics.raylib;

const keymap = @import("keymap.zig");


pub const KeyEvent = struct {

};


pub const Keyboard = struct {
    // Maybe make a interface for the cia1 connected device and let this be one implementation of it.
    keyboard_matrix: [8]u8,
    pub fn init() Keyboard {
        return Keyboard{
            .keyboard_matrix = [8]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
        };
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
        

        while (true) {
            
            var char: c_int = raylib.GetCharPressed();
            if (char == 0) break;
            // Ensure uppercase for alphanumeric
            if (char >= 'a' and char <= 'z') {
                char -= 32; 
            }
            const keymapping = keymap.lookup_c64_char(@intCast(char)) orelse continue;
            for (keymapping.keys) |keycode| {
                const key = keymap.lookup_c64_physical_key(keycode);
                self.set_key_down(key.row, key.col);
            }
            
        }
    }
};




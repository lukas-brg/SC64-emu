const std = @import("std");

const graphics = @import("graphics.zig");
const emu = @import("emulator.zig");
const cia = @import("cia.zig");
const _bus = @import("bus.zig");
const c = @import("cpu/cpu.zig");

const log_io = std.log.scoped(.io);
const raylib = graphics.raylib;

const keymap = @import("keymap.zig");
const runtime_info = @import("runtime_info.zig");

const keyevent_queue = @import("keyevent_queue.zig");
const paste_queue = @import("paste_queue.zig");

const KeyDownEvent = @import("keydown_event.zig").KeyDownEvent;



pub fn asciiToPetscii(char: u8) u8 {
    if (char >= 'a' and char <= 'z') {
        return char - 'a' + 0x41;        
    } else if (char >= 'A' and char <= 'Z') {
        return char - 'A' + 0xc1;
    }
    return char;
}


pub fn petsciiToScreencode(code: u8) u8 {
    if (code >= 0x40 and code <= 0x5f) {
        return (code - 0x40);
    } else if (code >= 0x60 and code <= 0x7f) {
        return (code - 0x20);
    } else if (code >= 0xa0 and code <= 0xbf) {
        return (code - 0x40);
    } else if (code >= 0xc0 and code <= 0xfe) {
        return (code - 0x80);
    } else if (code == 0xff) {
        return 0x5e;
    }  
    return code; 
}

pub inline fn asciiToScreencode(char: u8) u8 {
    if (char >= 'a' and char <= 'z') {
        return (char - 32) - 64;
    }
    
    if (char >= 'A' and char <= 'Z') {
        return char - 64;
    }
    return char;
}



pub const Keyboard = struct {
    // Maybe make a interface for the cia1 connected device and let this be one implementation of it.
    keyboard_matrix: [8]u8,
    last_paste_at_cycle: usize = 0,
    paste_last_insert_at: usize = 0,
    bus: *_bus.Bus,
    cpu: *c.CPU,

    pub fn init(bus: *_bus.Bus, cpu: *c.CPU) Keyboard {
        return Keyboard{
            .keyboard_matrix = [8]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
            .bus = bus,
            .cpu = cpu
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
                    // std.debug.print("releasing key {s} at {}\n", .{ @tagName(event.keycode), runtime_info.current_cycle });
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
                const cursor_row = self.bus.readRam(_bus.MemoryMap.cursor_row);
                const cursor_col = self.bus.readRam(_bus.MemoryMap.cursor_col);

                const offset = @as(u16 ,cursor_row) * 40 + cursor_col;
                const addr_start = _bus.MemoryMap.screen_mem_start + offset;

                for (slice, 0..slice.len) |_char, i| {
                    const char = _char;
                    const screencode = asciiToScreencode(char);
                    std.debug.print("screencode {x}  char {c}\n", .{screencode, char});
                    self.bus.writeRam(addr_start + @as(u16, @truncate(i)), screencode);

                }
                const paste_len = slice.len;
                const new_col: u8 = @truncate((@as(usize, cursor_col) + paste_len) % 40);
                const new_row: u8 = @truncate(cursor_row + (@as(usize, cursor_col) + paste_len) / 40);

                std.debug.print("new cursor col {}", .{new_col});
                self.bus.writeRam(_bus.MemoryMap.cursor_row, new_row);
                self.bus.writeRam(_bus.MemoryMap.cursor_col, new_col);
                self.cpu.irq();
                self.last_paste_at_cycle = runtime_info.current_cycle;
                self.paste_last_insert_at = runtime_info.current_cycle;
                
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

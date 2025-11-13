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

const keydown_queue = @import("keydown_queue.zig");

const MemoryMap = @import("memory_map.zig");
const KeyDownEvent = @import("keydown_event.zig").KeyDownEvent;

const charset = @import("charset.zig");

const SCREEN_ROWS: u8 = 25;
const SCREEN_COLS: u8 = 40;



pub const Keyboard = struct {
    // Maybe make a interface for the cia1 connected device and let this be one implementation of it.
    keyboard_matrix: [8]u8,
    last_paste_at_cycle: usize = 0,
    paste_last_insert_at: usize = 0,
    bus: *_bus.Bus,
    cpu: *c.CPU,

    pub fn init(bus: *_bus.Bus, cpu: *c.CPU) Keyboard {
        return Keyboard{ .keyboard_matrix = [8]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }, .bus = bus, .cpu = cpu };
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

    inline fn gridPosToScreenMemOffset(row: u8, col: u8) u16 {
        const offset = @as(u16, row) * SCREEN_COLS + col;
        return offset;
    }

    fn handlePaste(self: *Keyboard) bool {
         const clip: [*c]const u8 = @ptrCast(raylib.GetClipboardText());
            if (clip != null) {
                const len = std.mem.len(clip);
                const slice = clip[0..len];
                const cursor_row = self.bus.readRam(MemoryMap.cursor_row);
                const cursor_col = self.bus.readRam(MemoryMap.cursor_col);

                var effective_paste_len: usize = 0;
                var current_row = cursor_row;
                var current_col = cursor_col;
                for (slice) |char| {
                    const screencode = charset.asciiToScreencode(char) orelse 0x20;
                    switch (char) {
                        '\n' => {
                            current_row += 1;
                            current_col = 0;
                            std.debug.print("new line cursor row: {} \n", .{ current_row });
                        },
                        else => {
                            self.bus.writeScreenMem(gridPosToScreenMemOffset(current_row, current_col) , screencode);
                            current_row += (current_col + 1) / SCREEN_COLS;
                            current_col = (current_col + 1) % SCREEN_COLS;
                            effective_paste_len += 1;
                            std.debug.print("char {c} screencode {x:0>2} cursor col: {} \n", .{ char, screencode, current_col });
                        }   
                    }
                    
                }
                std.debug.print("writing cursor pos {} {}", .{current_row, cursor_col});
                self.bus.write(MemoryMap.cursor_row, current_row);
                self.bus.ram[214] = current_row;
                self.bus.write(0xC9, current_row);
                self.bus.writeRam(MemoryMap.cursor_col, current_col);
                self.last_paste_at_cycle = runtime_info.current_cycle;
                return true;
            }
            
            return false;
    }

    fn handleKeyReleases(self: *Keyboard) void {
        while (true) {
            if (keydown_queue.peek()) |event| {
                if (runtime_info.current_cycle - event.at_cycle >= 10000) {
                    _ = keydown_queue.dequeue();
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
    }


    pub fn update(self: *Keyboard) void {
        
        self.handleKeyReleases();

        if (raylib.IsKeyDown(raylib.KEY_LEFT_CONTROL) and raylib.IsKeyDown(raylib.KEY_V) and runtime_info.current_cycle - self.last_paste_at_cycle >= 800000) {
           const did_paste = self.handlePaste();
           if (did_paste) return;
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
                keydown_queue.enqueue(.{ .keycode = keycode, .at_cycle = runtime_info.current_cycle });
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

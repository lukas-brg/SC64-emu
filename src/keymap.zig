const std = @import("std");

pub const C64_KEY = enum {
    KEY_A,
    KEY_B,
    KEY_C,
    KEY_RETURN,
    KEY_COMMA,
    KEY_PLUS,
};

pub const PrintableKeyMapping = struct {
    key: C64_KEY,
    row: u3,
    col: u3,
    char: u8,
};

const _KEYTABLE_PRINTABLE = [_]PrintableKeyMapping{
    .{ .key = .KEY_A, .row = 2, .col = 1, .char = 'A' },
    .{ .key = .KEY_PLUS, .row = 0, .col = 5, .char = '+' },
};

const KEYMAP_PRINTABLE = blk: {
    var table: [256]?PrintableKeyMapping = [_]?PrintableKeyMapping{null} ** 256;
    for (0.._KEYTABLE_PRINTABLE.len) |i| {
        const entry = _KEYTABLE_PRINTABLE[i];
        table[entry.char] = entry;
    }
    break :blk table;
};

pub fn lookup_printable_key(key: u8) ?PrintableKeyMapping {
    return KEYMAP_PRINTABLE[key];
}

const std = @import("std");

pub const C64KeyCode = enum {
    KEY_DELETE,   
    KEY_RETURN,     
    KEY_CURSOR_RIGHT,
    KEY_F7,
    KEY_F1,
    KEY_F3,
    KEY_F5,
    KEY_CURSOR_DOWN,

    KEY_3,
    KEY_W,
    KEY_A,
    KEY_4,
    KEY_Z,
    KEY_S,
    KEY_E,
    KEY_SHIFT_LEFT,

    KEY_5,
    KEY_R,
    KEY_D,
    KEY_6,
    KEY_C,
    KEY_F,
    KEY_T,
    KEY_X,

    KEY_7,
    KEY_Y,
    KEY_G,
    KEY_8,
    KEY_B,
    KEY_H,
    KEY_U,
    KEY_V,

    KEY_9,
    KEY_I,
    KEY_J,
    KEY_0,
    KEY_M,
    KEY_K,
    KEY_O,
    KEY_N,

    KEY_PLUS,     
    KEY_P,
    KEY_L,
    KEY_MINUS,    
    KEY_PERIOD,    
    KEY_COLON,     
    KEY_AT,        
    KEY_COMMA,     

    KEY_POUND,     
    KEY_ASTERISK,  
    KEY_SEMICOLON, 
    KEY_HOME,      
    KEY_RIGHT_SHIFT,
    KEY_EQUALS,    
    KEY_ARROW_UP,  
    KEY_SLASH,     

    KEY_1,
    KEY_ARROW_LEFT,
    KEY_CONTROL,
    KEY_2,
    KEY_SPACE,
    KEY_COMMODORE,  
    KEY_Q,
    KEY_RUN_STOP,   
};

pub const C64Key = struct {
    keycode: C64KeyCode,
    row: u3,
    col: u3,
};

pub const C64_PHYSICAL_KEYS: []const C64Key = &.{
    .{ .keycode = .KEY_A, .row = 2, .col = 1 },
    .{ .keycode = .KEY_B, .row = 4, .col = 3 },
    .{ .keycode = .KEY_C, .row = 4, .col = 2 },
    .{ .keycode = .KEY_D, .row = 2, .col = 2 },
    .{ .keycode = .KEY_E, .row = 6, .col = 1 },
    .{ .keycode = .KEY_F, .row = 5, .col = 2 },
    .{ .keycode = .KEY_G, .row = 2, .col = 3 },
    .{ .keycode = .KEY_H, .row = 5, .col = 3 },
    .{ .keycode = .KEY_I, .row = 1, .col = 4 },
    .{ .keycode = .KEY_J, .row = 2, .col = 4 },
    .{ .keycode = .KEY_K, .row = 5, .col = 4 },
    .{ .keycode = .KEY_L, .row = 2, .col = 5 },
    .{ .keycode = .KEY_M, .row = 4, .col = 4 },
    .{ .keycode = .KEY_N, .row = 7, .col = 4 },
    .{ .keycode = .KEY_O, .row = 6, .col = 4 },
    .{ .keycode = .KEY_P, .row = 1, .col = 5 },
    .{ .keycode = .KEY_Q, .row = 6, .col = 7 },
    .{ .keycode = .KEY_R, .row = 1, .col = 2 },
    .{ .keycode = .KEY_S, .row = 5, .col = 1 },
    .{ .keycode = .KEY_T, .row = 6, .col = 2 },
    .{ .keycode = .KEY_U, .row = 6, .col = 3 },
    .{ .keycode = .KEY_V, .row = 7, .col = 3 },
    .{ .keycode = .KEY_W, .row = 1, .col = 1 },
    .{ .keycode = .KEY_X, .row = 7, .col = 2 },
    .{ .keycode = .KEY_Y, .row = 1, .col = 3 },
    .{ .keycode = .KEY_Z, .row = 4, .col = 1 },

    .{ .keycode = .KEY_SPACE, .row = 4, .col = 7 },
    .{ .keycode = .KEY_RETURN, .row = 1, .col = 0 },
    .{ .keycode = .KEY_PLUS, .row = 0, .col = 5 },
    .{ .keycode = .KEY_SHIFT_LEFT, .row = 7, .col = 1 },
    .{ .keycode = .KEY_COMMA, .row = 7, .col = 5 },
    .{ .keycode = .KEY_DELETE, .row = 0, .col = 0 },

    .{ .keycode = .KEY_1, .row = 0, .col = 7 },
    .{ .keycode = .KEY_2, .row = 3, .col = 7 },
    .{ .keycode = .KEY_3, .row = 0, .col = 1 },
    .{ .keycode = .KEY_4, .row = 3, .col = 1 },
    .{ .keycode = .KEY_5, .row = 0, .col = 2 },
    .{ .keycode = .KEY_6, .row = 3, .col = 2 },
    .{ .keycode = .KEY_7, .row = 0, .col = 3 },
    .{ .keycode = .KEY_8, .row = 3, .col = 3 },
    .{ .keycode = .KEY_9, .row = 0, .col = 4 },
    .{ .keycode = .KEY_0, .row = 3, .col = 4 },
};


const _CHAR_TABLE = [_]C64CharKeyMapping{
    .{ .char = 'A', .keys = &.{.KEY_A} },
    .{ .char = 'B', .keys = &.{.KEY_B} },
    .{ .char = '+', .keys = &.{.KEY_PLUS} },
    .{ .char = '"', .keys = &.{.KEY_SHIFT_LEFT, .KEY_2} },
};


pub const C64_PHYSICAL_KEY_LOOKUP_TABLE = blk: {
    var table: [@typeInfo(C64KeyCode).Enum.fields.len]C64Key = undefined;

    for (C64_PHYSICAL_KEYS) |entry| {
        const idx = @intFromEnum(entry.keycode);
        table[idx] = entry;
    }
    break :blk table;
};


pub const C64CharKeyMapping = struct {
    char: u8,
    keys: [] const C64KeyCode,
};


const C64_CHAR_LOOKUP_TABLE = blk: {
    var table: [256]?C64CharKeyMapping = [_]?C64CharKeyMapping{null} ** 256;
    for (0.._CHAR_TABLE.len) |i| {
        const entry = _CHAR_TABLE[i];
        table[entry.char] = entry;
    }
    break :blk table;
};

pub inline fn lookup_c64_physical_key(key: C64KeyCode) C64Key {
    return C64_PHYSICAL_KEY_LOOKUP_TABLE[@intFromEnum(key)];
}

pub inline fn lookup_c64_char(host_char: u8) ?C64CharKeyMapping {
    return C64_CHAR_LOOKUP_TABLE[host_char];
}

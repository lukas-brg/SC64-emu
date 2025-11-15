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

pub fn asciiToScreencode(char: u8) ?u8 {
    return switch (char) {
        'a'...'z' => char - 96,
        'A'...'Z' => char - 64,
        '0'...'9' => char,
        '@' => 0,
        '[' => 0x1B,
        ']' => 0x1D,
        ' ' => 0x20,
        '!' => 0x21,
        '"' => 0x22,
        '#' => 0x23,
        '$' => 0x24,
        '%' => 0x25,
        '&' => 0x26,
        '`' => 0x27,
        '(' => 0x28,
        ')' => 0x29,
        '*' => 0x2A,
        '+' => 0x2B,
        ',' => 0x2C,
        '-' => 0x2D,
        '.' => 0x2E,
        '/' => 0x2F,
        ':' => 0x3A,
        ';' => 0x3B,
        '<' => 0x3C,
        '=' => 0x3D,
        '>' => 0x3E,
        '?' => 0x3F,
        else => null,
    };
}
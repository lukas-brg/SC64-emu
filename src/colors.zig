
const ColorRGB = struct {
    r: u8,
    g: u8,
    b: u8,
};


pub const C64_COLOR_PALETTE = [16]ColorRGB {
    .{.r=0,   .g=0,   .b=0},      // black
    .{.r=255, .g=255, .b=255},    // White
    .{.r=136, .g=0, .  b=0},      // Red
    .{.r=170, .g=255, .b=238},    // cyan
    
    .{.r=204, .g=68,  .b=204},    // Violet
    .{.r=0,   .g=204, .b=85},     // green
    .{.r=72,  .g=56,  .b=170},    // blue / bg color 
    .{.r=238, .g=238, .b=119},    // yellow
    
    .{.r=221, .g=136, .b=85},     // orange
    .{.r=102, .g=68,  .b=0},      // brown
    .{.r=255, .g=119, .b=119},    // light red
    .{.r=51,  .g=51,  .b=51},     // dark grey
    
    .{.r=119, .g=119, .b=119},    // grey 2
    .{.r=170, .g=255, .b=102},    // light green
    .{.r=134, .g=122, .b=222},    // light blue / text color
    .{.r=187, .g=187, .b=187},    // light grey
};


pub const BG_COLOR = 6;
pub const TEXT_COLOR = 14; 
pub const FRAME_COLOR = 14;
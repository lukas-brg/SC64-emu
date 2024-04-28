const std = @import("std");
pub inline fn combine_bytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

pub inline fn split_into_bytes(val: u16) [2]u8 {
    const low: u8 = @truncate(val & 0xFF);
    const high: u8 = @truncate((val & 0xFF00) >> 8);
    const bytes = [2]u8{low, high};
    return bytes;
}   

pub inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
    return @intCast((byte >> bit_index) & 1);
}


pub fn set_bit_at(byte: u8, bit_index: u3, val: u1) u8 {
    var result = byte & ~(@as(u8, 1) << bit_index); // clear bit
    result |= (@as(u8, val) << bit_index); // set bit
    return result;
}


pub fn rotate_left(byte: u8, n: u8) u8 {
    const x: u8 = @intCast(8 - n);
    return ((byte << @intCast(n)) | ((byte >> @intCast(x)) & 0x0f));
}

pub fn rotate_right(byte: u8, n: u8) u8 {
    const x: u8 = @intCast(8 - n);
    return ((byte >> @intCast(n)) | ((byte << @intCast(x)) & 0x0f));
}

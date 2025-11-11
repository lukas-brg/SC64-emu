const std = @import("std");

pub inline fn combineBytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

pub inline fn splitIntoBytes(val: u16) [2]u8 {
    const low: u8 = @truncate(val);
    const high: u8 = @truncate(val >> 8);
    const bytes = [2]u8{ low, high };
    return bytes;
}

// pub inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
//     return @intCast((byte >> bit_index) & 1);
// }

pub inline fn getBitAt(byte: u8, bit_index: u3) u1 {
    return @truncate(byte >> bit_index);
}

pub inline fn setBitAt(byte: u8, bit_index: u3, val: u1) u8 {
    var result = byte & ~(@as(u8, 1) << bit_index); // clear bit
    result |= (@as(u8, val) << bit_index); // set bit
    return result;
}

pub inline fn rotateLeft(byte: u8, comptime n: u8) u8 {
    const x: u8 = comptime 8 -% n;
    return ((byte << n) | ((byte >> x) & 0x0f));
}

pub inline fn rotateRight(byte: u8, comptime n: u8) u8 {
    const x: u8 = comptime (8 -% n);
    return ((byte >> n) | ((byte << x) & 0x0f));
}

pub inline fn splitIntoNibbles(byte: u8) [2]u4 {
    const low: u4 = @truncate(byte);
    const high: u4 = @truncate(byte >> 4);
    return [2]u4{ low, high };
}

pub inline fn didCarryIntoBit(a: u8, b: u8, res: u8, comptime nbit: u3) bool {
    const mask = comptime (1 << nbit);
    return mask & (a ^ b ^ res) != 0;
}

pub inline fn didCarryOutOfBit(a: u8, b: u8, res: u8, comptime nbit: u3) bool {
    const mask = comptime (1 << nbit);
    return mask & (a | b) & ((a & b) | ~res) != 0;
}

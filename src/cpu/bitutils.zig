
pub inline fn combine_bytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

pub inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
    return @intCast((byte >> bit_index) & 1);
}


pub fn set_bit_at(byte: u8, bit_index: u3, val: u1) u8 {
    var result = byte & ~(@as(u8, 1) << bit_index); // clear bit
    result |= (@as(u8, val) << bit_index); // set bit
    return result;
}
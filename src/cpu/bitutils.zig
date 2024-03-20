
pub inline fn combine_bytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

pub inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
    return @intCast((byte >> bit_index) & 1);
}

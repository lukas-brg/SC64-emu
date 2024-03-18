const std = @import("std");
const fs = std.fs;
const mem = @import("std").mem;

pub fn load_rom_data(rom_path: []const u8) ![]u8 {

    const file = try fs.cwd().openFile(rom_path, .{});
    defer file.close();


    const file_size = try file.seekEnd(0);
    try file.seek(0, fs.SeekSet);


    const rom_data = try mem.alloc(u8, file_size);


    try file.readFull(rom_data);

    return rom_data;
}
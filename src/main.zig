const std = @import("std");
const c = @import("cpu/cpu.zig");
const Bus = @import("bus.zig").Bus;
const CPU = @import("cpu/cpu.zig").CPU;
const Emulator = @import("emulator.zig").Emulator;
const EmulatorConfig = @import("emulator.zig").EmulatorConfig;
const graphics = @import("graphics.zig");

pub fn load_rom_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const rom_data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return rom_data;
}




pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
   
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var rom_path: []const u8 = "test.o65";
    
    if (args.len > 1){
        rom_path = args[1];
    }
    
    const config = EmulatorConfig{};
    var emulator = try Emulator.init(allocator, config);
    defer emulator.deinit(allocator);
    //emulator.cpu.set_reset_vector(0x0040);

    _ = try emulator.load_rom(rom_path, 0);

    try emulator.init_c64();
    //emulator.bus.write(0x400, 1);
    try emulator.run(null);
    //_ = try graphics.sdl_test();

}

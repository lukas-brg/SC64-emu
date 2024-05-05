const std = @import("std");
const c = @import("cpu/cpu.zig");
const Bus = @import("bus.zig").Bus;
const CPU = @import("cpu/cpu.zig").CPU;
const Emulator = @import("emulator.zig").Emulator;
const EmulatorConfig = @import("emulator.zig").EmulatorConfig;
const clap = @import("clap");

pub fn load_rom_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const rom_data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return rom_data;
}

pub fn cpu_functional_test() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
   
    const allocator = gpa.allocator();
    const rom_path: []const u8 = "test_files/cpu/6502_functional_test.bin";
    
    var emulator = try Emulator.init(allocator, .{.scaling_factor = 4, .headless = true});
    emulator.bus.enable_bank_switching = false;
    defer emulator.deinit(allocator);

    _ = try emulator.load_rom(rom_path, 0);

    emulator.cpu.set_reset_vector(0x400);
    //try emulator.init_c64();
    try emulator.run(1_000_000);
}



pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
   
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--ftest                Run a functional cpu test
        \\-h, --headless         No graphical output
        \\-r, --rom <str>        Run a custom rom on a blank machine rather than KERNAL
        \\-o, --offset <u16>           Specify the starting position of the custom rom
        \\-s, --scaling <f32>  Specify a scaling factor, as 320x200 will be very small on modern screens
        \\--pc <u16>             Specify the initial Program Counter
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    const headless = res.args.headless != 0;
    const scaling_factor = res.args.scaling orelse 4;

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if(res.args.ftest != 0) {
        try cpu_functional_test();
    } 
    else if (res.args.rom) |rom_path| {
        var emulator = try Emulator.init(allocator, .{.headless = headless, .scaling_factor = scaling_factor, .enable_bank_switching = false});
        try emulator.init_graphics();
        defer emulator.deinit(allocator);
        _ = try emulator.load_rom(rom_path, res.args.offset orelse 0x1000); // 0x1000 is chosen as a default here since xa65 also uses it by default
        emulator.cpu.set_reset_vector( res.args.pc orelse 0x1000);

        try emulator.run(null);
    }
    else {
        var emulator = try Emulator.init(allocator, .{.scaling_factor = scaling_factor, .headless = headless});
        defer emulator.deinit(allocator);
        try emulator.init_c64();
        try emulator.run(null);
    }
}


fn test_init_reset_vector(bus: *Bus) void {
    // Reset vector to 0x2010
    bus.write(0xfffc, 0x10);
    bus.write(0xfffd, 0x20);
}


test "loading reset vector into pc" {
    const assert = std.debug.assert;
    var bus = Bus{};  
    var cpu = c.CPU.init(&bus);
    test_init_reset_vector(&bus);
    cpu.reset();

    assert(cpu.PC == 0x2010);
}

test "set status flag" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();

    cpu.set_status_flag(c.StatusFlag.BREAK, 1);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);

    cpu.toggle_status_flag(c.StatusFlag.BREAK);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 1);

    cpu.set_status_flag(c.StatusFlag.BREAK, 0);
    assert(cpu.get_status_flag(c.StatusFlag.BREAK) == 0);
}

test "stack operations" {
    const assert = std.debug.assert;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();
    cpu.push(0x4D);
    assert(cpu.pop() == 0x4D);
}


test "test opcode lookup" {
    const assert = std.debug.assert;
    const decode_opcode = @import("cpu/opcodes.zig").decode_opcode;
    var bus = Bus{};
    var cpu = c.CPU.init(&bus);
    cpu.reset();

    const instruction = decode_opcode(0xEA);
    assert(std.mem.eql(u8, instruction.op_name, "NOP"));
}


test "cpu and bus allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const rom_path: []const u8 = "test.o65";
    var emulator = try Emulator.init(allocator);

    _ = try emulator.load_rom(rom_path, 0);

    std.debug.assert(std.mem.eql(u8, &emulator.bus.ram, &emulator.cpu.bus.ram));
    std.debug.assert(emulator.bus == emulator.cpu.bus);

    emulator.run(null);

    std.debug.assert(std.mem.eql(u8, &emulator.bus.ram, &emulator.cpu.bus.ram));
    std.debug.assert(emulator.bus == emulator.cpu.bus);

    emulator.deinit(allocator);
} 
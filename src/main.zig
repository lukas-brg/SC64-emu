const std = @import("std");
const c = @import("cpu/cpu.zig");
const Bus = @import("bus.zig").Bus;
const CPU = @import("cpu/cpu.zig").CPU;
const Emulator = @import("emulator.zig").Emulator;
const EmulatorConfig = @import("emulator.zig").EmulatorConfig;
const DebugTraceConfig = @import("emulator.zig").DebugTraceConfig;
const clap = @import("clap");
const builtin = @import("builtin");

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => std.log.Level.debug,
        .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
    },
};



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

    const params = comptime clap.parseParamsComptime(
        \\-h, --help                 Display this help and exit.
        \\--ftest                    Run a functional cpu test
        \\--headless                 No graphical output
        \\-r, --rom <str>            Run a custom rom on a blank machine instead of KERNAL
        \\-o, --offset <u16>         Specify the starting position of the custom rom
        \\-s, --scaling <f32>        Specify a scaling factor, as 320x200 will be very small on modern screens
        \\-c, --cycles <usize>       Specify the number of cycles to be executed
        \\-i, --instructions <usize> Specify the number of instructions to be executed
        \\-d, --disable_trace        Disable debug trace
        \\-t, --trace                Enable debug trace
        \\--trace_start <usize>      Start debug trace at cycle no 
        \\--trace_addr <u16>         Trace a single address specified here
        \\--trace_end <usize>        End debug trace at cycle no 
        \\--trace_start_ins <usize>  Start debug trace at instruction no
        \\--pc <u16>                 Specify the initial Program Counter
        \\--nobankswitch             Disable bank switching
        \\-v, --trace_verbose 
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

    const default_emu_config = EmulatorConfig{};
    const default_dbg_config = DebugTraceConfig{};
    const headless = res.args.headless != 0;
    const scaling_factor = res.args.scaling orelse default_emu_config.scaling_factor;
    const trace_start_i = res.args.trace_start_ins orelse default_dbg_config.start_at_instr;
    
    const trace_start = res.args.trace_start orelse default_dbg_config.start_at_cycle;
    const trace: bool = (res.args.trace != 0 or default_dbg_config.enable_trace) and (res.args.disable_trace == 0);
    const trace_end = res.args.trace_end;


    const bank_switching = (res.args.nobankswitch == 0) and default_emu_config.enable_bank_switching;
    const verbose = (res.args.trace_verbose != 0) or default_dbg_config.verbose;

    var emu_config = EmulatorConfig{ 
        .headless = headless, 
        .scaling_factor = scaling_factor, 
        .enable_bank_switching = bank_switching,
    };

    const trace_config = DebugTraceConfig{ 
        .enable_trace = trace, 
        .start_at_cycle = trace_start, 
        .start_at_instr = trace_start_i,
        .end_at_cycle = trace_end, 
        .verbose = verbose,
        .capture_addr = res.args.trace_addr,
    };

    if (res.args.help != 0) {
        return clap.help(std.io.getStdOut().writer(), clap.Help, &params, .{});
    }

    if (res.args.ftest != 0) {
        const rom_path: []const u8 = "test_files/6502_65C02_functional_tests/bin_files/6502_functional_test.bin";
        const cycles = res.args.cycles;

        emu_config.headless = true;
        var emulator = try Emulator.init(allocator, emu_config);

        defer emulator.deinit(allocator);
        emulator.set_trace_config(trace_config);
        emulator.bus.enable_bank_switching = false;
        _ = try emulator.load_rom(rom_path, 0);
        emulator.cpu.set_reset_vector(0x400);
        try emulator.run(cycles);
    } else if (res.args.rom) |rom_path| {
        emu_config.enable_bank_switching = false;
        var emulator = try Emulator.init(allocator, emu_config);

        emulator.set_trace_config(trace_config);
        try emulator.init_graphics();
        defer emulator.deinit(allocator);
        const offset = res.args.offset orelse 0x1000;
        emulator.cpu.set_reset_vector(res.args.pc orelse 0x1000);
        _ = try emulator.load_rom(rom_path, offset); // 0x1000 is chosen as a default here since xa65 also uses it by default
        try emulator.run(res.args.cycles);
        emulator.bus.print_mem(0x210, 0x211);
    } else {
        var emulator = try Emulator.init(allocator, emu_config);
        emulator.set_trace_config(trace_config);
        defer emulator.deinit(allocator);
        try emulator.init_c64();
        try emulator.run(res.args.cycles);
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

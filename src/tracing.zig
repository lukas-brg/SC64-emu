const Emulator = @import("emulator.zig").Emulator;
const CPU = @import("./cpu/cpu.zig").CPU;
const STACK_BASE_POINTER = @import("./cpu/cpu.zig").STACK_BASE_POINTER;
const Instruction = @import("./cpu/instruction.zig").Instruction;
const std = @import("std");


pub fn printTrace(emu: *Emulator) void {
    const cfg = emu.trace_config;

    const do_print_trace: bool = blk: {
        if (emu.__tracing_active) break :blk true;
        const cycle = emu.cpu.cycle_count;
        const instr = emu.cpu.instruction_count;
        const addr = emu.cpu.current_instruction.?.instruction_addr;

        if (cfg.capture_addr) |caddr| {
            if (addr == caddr) {
                break :blk true;
            }
        }
        if (!cfg.enable_trace) {
            break :blk false;
        }

        if (cfg.end_at_cycle) |endc| {
            if (cycle > endc) {
                break :blk false;
            }
        }

        if (cfg.start_at_cycle > cfg.start_at_instr) {
            break :blk cycle >= cfg.start_at_cycle;
        } else {
            break :blk instr >= cfg.start_at_instr;
        }
    };

    if (do_print_trace) {
        if (cfg.verbose) {
            const mem_window_size: i32 = @intCast(emu.trace_config.print_mem_window_size);
            const start: u16 = @intCast(@max(0, @as(i32, @intCast(emu.cpu.PC)) - @divFloor(mem_window_size, 2)));
            const end = @min(emu.bus.mem_size, @as(u17, start) + mem_window_size);

            if (emu.trace_config.print_cpu_state) {
                printCpuState(emu.cpu);
            }

            if (emu.trace_config.print_stack) {
                printStack(emu.cpu, emu.trace_config.print_stack_limit);
            }

            if (emu.trace_config.print_mem) {
                emu.cpu.bus.printMem(start, @intCast(end));
                emu.cpu.bus.printMem(0xc0, @intCast(0xc9));
            }
        } else {
            printCpuStateCompact(emu.cpu);
        }
    }
}

pub fn printDisassemblyInline(cpu: *CPU, instruction: Instruction) void {
    const PC = instruction.instruction_addr;
    switch (instruction.addressing_mode) {
        .ABSOLUTE => std.debug.print("{X:0>4}:  {s} ${X:0>4}{s: <4}", .{ PC, instruction.mnemonic, instruction.operand_addr.?, "" }),
        .ABSOLUTE_X => std.debug.print("{X:0>4}:  {s} ${X:0>4},X{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read16(PC + 1), "" }),
        .ABSOLUTE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>4},Y{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read16(PC + 1), "" }),
        .IMPLIED, .ACCUMULATOR => std.debug.print("{X:0>4}:  {s}{s: <10}", .{ PC, instruction.mnemonic, "" }),
        .INDIRECT => std.debug.print("{X:0>4}:  {s} (${X:0>4}){s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read16(PC + 1), "" }),
        .INDIRECT_Y => std.debug.print("{X:0>4}:  {s} (${X:0>2}),Y{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .INDIRECT_X => std.debug.print("{X:0>4}:  {s} (${X:0>2},X){s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .IMMEDIATE => std.debug.print("{X:0>4}:  {s} #${X:0>2}{s: <5}", .{ PC, instruction.mnemonic, instruction.operand.?, "" }),
        .ZEROPAGE => std.debug.print("{X:0>4}:  {s} ${X:0>2}{s: <6}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .ZEROPAGE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>2},Y{s: <4}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .ZEROPAGE_X => std.debug.print("{X:0>4}:  {s} ${X:0>2},X{s: <4}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .RELATIVE => std.debug.print("{X:0>4}:  {s} ${X:0>2}{s: <6}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
    }
}

pub fn printDisassembly(cpu: *CPU, instruction: Instruction) void {
    printDisassemblyInline(cpu, instruction);
    std.debug.print("\n", .{});
}

pub fn printStack(self: *CPU, limit: usize) void {
    var sp_abs = STACK_BASE_POINTER + @as(u16, self.SP) + 1;
    var count: usize = 0;
    std.debug.print("STACK:\n", .{});
    while (sp_abs <= STACK_BASE_POINTER + 0xFF and count < limit) {
        std.debug.print("{x:0>4}: {x:0>2}\n", .{ sp_abs, self.bus.read(sp_abs) });
        sp_abs += 1;
        count += 1;
    }
}

pub fn printCpuStateCompact(self: *CPU) void {
    const instruction = self.current_instruction orelse unreachable;
    printDisassemblyInline(self, instruction);
    if (instruction.operand_addr) |addr| {
        std.debug.print(" {X:0>4}  ", .{addr});
    } else {
        std.debug.print("  --   ", .{});
    }

    if (instruction.operand) |op| {
        std.debug.print("{X:0>2}  ", .{op});
    } else {
        std.debug.print("--  ", .{});
    }

    std.debug.print("|  AC={X:0>2}  XR={X:0>2}  YR={X:0>2}  SP={X:0>2}  |  n={} v={} d={} i={} z={} c={}  |  {} {}  |  ", .{
        self.A,
        self.X,
        self.Y,
        self.SP,
        self.status.negative,
        self.status.overflow,
        self.status.decimal,
        self.status.interrupt_disable,
        self.status.zero,
        self.status.carry,
        self.instruction_count,
        self.cycle_count,
    });

    for (instruction.instruction_addr..instruction.instruction_addr + instruction.bytes) |addr| {
        std.debug.print("{X:0>2} ", .{self.bus.read(@intCast(addr))});
    }

    std.debug.print("\n", .{});
}

pub fn printCpuState(cpu: *CPU) void {
    std.debug.print("\n----------------------------------------------------", .{});
    std.debug.print("\nCPU STATE:", .{});

    std.debug.print("\nPC: {b:0>16}", .{cpu.PC});
    std.debug.print("    {x:0>4}", .{cpu.PC});

    std.debug.print("\nSP:         {b:0>8}", .{cpu.SP});
    std.debug.print("      {x:0>2}", .{cpu.SP});

    std.debug.print("\nP:          {b:0>8}", .{cpu.status.toByte()});
    std.debug.print("      {x:0>2}", .{cpu.status.toByte()});

    std.debug.print("\nA:          {b:0>8}", .{cpu.A});
    std.debug.print("      {x:0>2}", .{cpu.A});

    std.debug.print("\nX:          {b:0>8}", .{cpu.X});
    std.debug.print("      {x:0>2}", .{cpu.X});

    std.debug.print("\nY:          {b:0>8}", .{cpu.Y});
    std.debug.print("      {x:0>2}", .{cpu.Y});

    std.debug.print("\n\nSTATUS FLAGS:", .{});
    std.debug.print("\nN V - B D I Z C", .{});

    std.debug.print("\n{} {} {} {} {} {} {} {} ", .{
        cpu.status.negative,
        cpu.status.overflow,
        cpu.status.unused,
        cpu.status.break_flag,
        cpu.status.decimal,
        cpu.status.interrupt_disable,
        cpu.status.zero,
        cpu.status.carry,
    });

    std.debug.print("\n----------------------------------------------------\n\n", .{});
}

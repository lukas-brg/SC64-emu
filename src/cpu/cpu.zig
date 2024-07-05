const std = @import("std");
const Bus = @import("../bus.zig").Bus;

const bitutils = @import("bitutils.zig");

const decode_opcode = @import("opcodes.zig").decode_opcode;
const get_bit_at = @import("bitutils.zig").get_bit_at;
const OpcodeInfo = @import("opcodes.zig").OpcodeInfo;
const Instruction = @import("instruction.zig").Instruction;
const get_instruction = @import("instruction.zig").get_instruction;

const log_cpu = std.log.scoped(.cpu);


const RESET_VECTOR = 0xFFFC;
const IRQ_VECTOR = 0xFFFE;
const NMI_VECTOR = 0xFFFA;

const STACK_BASE_POINTER: u16 = 0x100;

pub const StatusFlag = enum(u3) {
    CARRY,
    ZERO,
    INTERRUPT_DISABLE,
    DECIMAL,
    BREAK,
    UNUSED,
    OVERFLOW,
    NEGATIVE,
};

pub fn print_disassembly_inline(cpu: CPU, instruction: Instruction) void {
    const PC = instruction.instruction_addr;
    switch (instruction.addressing_mode) {
        .ABSOLUTE => std.debug.print("{X:0>4}:  {s} ${X:0>4}{s: <4}", .{ PC, instruction.mnemonic, instruction.operand_addr.?, "" }),
        .ABSOLUTE_X => std.debug.print("{X:0>4}:  {s} ${X:0>4},X{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read_16(PC + 1), "" }),
        .ABSOLUTE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>4},Y{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read_16(PC + 1), "" }),
        .IMPLIED, .ACCUMULATOR => std.debug.print("{X:0>4}:  {s}{s: <10}", .{ PC, instruction.mnemonic, "" }),
        .INDIRECT => std.debug.print("{X:0>4}:  {s} (${X:0>4}){s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read_16(PC + 1), "" }),
        .INDIRECT_Y => std.debug.print("{X:0>4}:  {s} (${X:0>2}),Y{s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .INDIRECT_X => std.debug.print("{X:0>4}:  {s} (${X:0>2},X){s: <2}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .IMMEDIATE => std.debug.print("{X:0>4}:  {s} #${X:0>2}{s: <5}", .{ PC, instruction.mnemonic, instruction.operand.?, "" }),
        .ZEROPAGE => std.debug.print("{X:0>4}:  {s} ${X:0>2}{s: <6}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .ZEROPAGE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>2},Y{s: <4}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .ZEROPAGE_X => std.debug.print("{X:0>4}:  {s} ${X:0>2},X{s: <4}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
        .RELATIVE => std.debug.print("{X:0>4}:  {s} ${X:0>2}{s: <6}", .{ PC, instruction.mnemonic, cpu.bus.read(PC + 1), "" }),
    }
}

pub fn print_disassembly(cpu: CPU, instruction: Instruction) void {
    print_disassembly_inline(cpu, instruction);
    std.debug.print("\n", .{});
}

pub const CPU = struct {
    /// Implementation of the 6502 microprocessor
    PC: u16,
    SP: u8,
    status: u8,
    A: u8,
    X: u8,
    Y: u8,
    bus: *Bus,
    instruction_count: usize = 0,
    cycle_count: usize = 0,
    instruction_remaining_cycles: usize = 0,
    current_instruction: ?Instruction = null,
    halt: bool = false,
    print_debug_info: bool = true,

    pub fn init(bus: *Bus) CPU {
        const cpu = CPU{
            .PC = 0,
            .SP = 0xFF,
            .status = 0b00100100,
            .A = 0,
            .X = 0,
            .Y = 0,
            .bus = bus,
        };

        return cpu;
    }

    pub fn reset(self: *CPU) void {
        self.PC = self.bus.read(RESET_VECTOR) | (@as(u16, self.bus.read(RESET_VECTOR + 1)) << 8);
        log_cpu.debug("CPU Reset. Loaded PC from reset vector: {X:0>4}", .{self.PC});
    }

    pub fn irq(self: *CPU) void {
        if (self.get_status_flag(StatusFlag.INTERRUPT_DISABLE) == 0) {
            self.push_16(self.PC);
            self.status = bitutils.set_bit_at(self.status, StatusFlag.UNUSED, 0);
            self.push(self.status);
            self.PC = self.bus.read_16(IRQ_VECTOR);
            log_cpu.debug("IRQ");
        } else {
            log_cpu.debug("IRQ (masked)");
        }
    }

    pub fn nmi(self: *CPU) void {
        self.push_16(self.PC);
        self.status = bitutils.set_bit_at(self.status, StatusFlag.UNUSED, 0);
        self.push(self.status);
        self.PC = self.bus.read_16(NMI_VECTOR);
        log_cpu.debug("NMI");
    }

    fn get_status_bit(self: CPU, bit_index: u3) u1 {
        return @intCast((self.status >> bit_index) & 1);
    }

    pub fn get_status_flag(self: CPU, flag: StatusFlag) u1 {
        return self.get_status_bit(@intFromEnum(flag));
    }

    pub fn set_status_flag(self: *CPU, flag: StatusFlag, val: u1) void {
        const bit_index = @intFromEnum(flag);
        self.status &= ~(@as(u8, 1) << bit_index); // clear bit
        self.status |= (@as(u8, val) << bit_index); // set bit
    }

    pub fn update_negative(self: *CPU, result: u8) void {
        self.set_status_flag(StatusFlag.NEGATIVE, get_bit_at(result, 7));
    }

    pub fn update_zero(self: *CPU, result: u8) void {
        self.set_status_flag(StatusFlag.ZERO, @intFromBool(result == 0));
    }

    pub fn toggle_status_flag(self: *CPU, flag: StatusFlag) void {
        const bit_index = @intFromEnum(flag);
        self.status ^= (@as(u8, 1) << bit_index);
    }

    pub fn pop(self: *CPU) u8 {
        self.SP +%= 1;
        if (self.SP == 0) log_cpu.debug("Stack overflow (Pop)  [PC: {X:0>4}, OP: {s}, Cycle: {}, #Instruction: {}]", .{
                    self.current_instruction.?.instruction_addr,
                    self.current_instruction.?.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
        return self.bus.read(STACK_BASE_POINTER + self.SP);
    }

    pub fn pop_16(self: *CPU) u16 {
        const low_byte = @as(u16, self.pop());
        const high_byte = @as(u16, self.pop());
        return (high_byte << 8) | low_byte;
    }

    pub fn push(self: *CPU, val: u8) void {
        self.bus.write(STACK_BASE_POINTER + self.SP, val);
        if (self.SP == 0) log_cpu.debug("Stack overflow (Push) [PC: {X:0>4}, OP: {s}, Cycle: {}, #Instruction: {}]", .{
                    self.current_instruction.?.instruction_addr,
                    self.current_instruction.?.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
        self.SP -%= 1;
    }

    pub fn push_16(self: *CPU, val: u16) void {
        const high_byte: u8 = @intCast(val >> 8);
        self.push(high_byte);

        const low_byte: u8 = @intCast(val & 0xFF);
        self.push(low_byte);
    }

    fn fetch_byte(self: CPU) u8 {
        return self.bus.read(self.PC);
    }

    pub fn set_reset_vector(self: *CPU, addr: u16) void {
        self.bus.write_16(RESET_VECTOR, addr);
    }

    pub fn print_stack(self: *CPU, limit: usize) void {
        var sp_abs = STACK_BASE_POINTER + @as(u16, self.SP) + 1;
        var count: usize = 0;
        std.debug.print("STACK:\n", .{});
        while (sp_abs <= STACK_BASE_POINTER + 0xFF and count < limit) {
            std.debug.print("{x:0>4}: {x:0>2}\n", .{ sp_abs, self.bus.read(sp_abs) });
            sp_abs += 1;
            count += 1;
        }
    }

    pub fn clock_tick(self: *CPU) void {
        if (self.instruction_remaining_cycles > 0) {
            self.instruction_remaining_cycles -= 1;
        } else {
            self.step();
        }
    }

    /// Executes the next instruction in a single step
    pub fn step(self: *CPU) void {
        self.instruction_remaining_cycles = 0;
        const d_prev = self.get_status_flag(StatusFlag.DECIMAL);
      
        const opcode = self.fetch_byte();
        
        const opcode_info = decode_opcode(opcode) orelse { 
            std.debug.panic("Illegal opcode {X:0>2} at {X:0>4}", .{ opcode, self.PC });
        };
       
        const instruction = get_instruction(self, opcode_info);
        self.current_instruction = instruction;
        if (self.print_debug_info) {
            print_disassembly(self.*, instruction);
            opcode_info.print();
            instruction.print();
        }

        opcode_info.handler_fn(self, instruction);
        self.cycle_count += self.instruction_remaining_cycles;
        self.instruction_count += 1;
        const d_curr = self.get_status_flag(StatusFlag.DECIMAL);
        if (d_curr != d_prev) {
            if (d_curr == 1) {
                log_cpu.debug("Decimal mode activated.   [PC: {X:0>4}, OP: {s}, Cycle: {}, #Instruction: {}]", .{
                    instruction.instruction_addr,
                    instruction.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
            } else {
                log_cpu.debug("Decimal mode deactivated. [PC: {X:0>4}, OP: {s}, Cycle: {}, #Instruction: {}]", .{
                    instruction.instruction_addr,
                    instruction.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
            }
        }
    }

    pub fn print_state_compact(self: CPU) void {
        const instruction = self.current_instruction orelse unreachable;
        print_disassembly_inline(self, instruction);
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
            self.get_status_flag(StatusFlag.NEGATIVE),
            self.get_status_flag(StatusFlag.OVERFLOW),
            self.get_status_flag(StatusFlag.DECIMAL),
            self.get_status_flag(StatusFlag.INTERRUPT_DISABLE),
            self.get_status_flag(StatusFlag.ZERO),
            self.get_status_flag(StatusFlag.CARRY),
            self.instruction_count,
            self.cycle_count,
        });

        for (instruction.instruction_addr..instruction.instruction_addr + instruction.bytes) |addr| {
            std.debug.print("{X:0>2} ", .{self.bus.read(@intCast(addr))});
        }

        std.debug.print("\n", .{});
    }

    pub fn print_state(self: CPU) void {
        std.debug.print("\n----------------------------------------------------", .{});
        std.debug.print("\nCPU STATE:", .{});

        std.debug.print("\nPC: {b:0>16}", .{self.PC});
        std.debug.print("    {x:0>4}", .{self.PC});

        std.debug.print("\nSP:         {b:0>8}", .{self.SP});
        std.debug.print("      {x:0>2}", .{self.SP});

        std.debug.print("\nP:          {b:0>8}", .{self.status});
        std.debug.print("      {x:0>2}", .{self.status});

        std.debug.print("\nA:          {b:0>8}", .{self.A});
        std.debug.print("      {x:0>2}", .{self.A});

        std.debug.print("\nX:          {b:0>8}", .{self.X});
        std.debug.print("      {x:0>2}", .{self.X});

        std.debug.print("\nY:          {b:0>8}", .{self.Y});
        std.debug.print("      {x:0>2}", .{self.Y});

        std.debug.print("\n\nSTATUS FLAGS:", .{});
        std.debug.print("\nN V - B D I Z C", .{});

        std.debug.print("\n{} {} {} {} {} {} {} {} ", .{ 
            self.get_status_bit(7), 
            self.get_status_bit(6), 
            self.get_status_bit(5), 
            self.get_status_bit(4), 
            self.get_status_bit(3), 
            self.get_status_bit(2), 
            self.get_status_bit(1),
            self.get_status_bit(0), 
        });

        std.debug.print("\n----------------------------------------------------\n\n", .{});
    }
};

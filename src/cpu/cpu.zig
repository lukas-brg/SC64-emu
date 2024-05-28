
const std = @import("std");
const Bus = @import("../bus.zig").Bus;

const bitutils = @import("bitutils.zig");

const decode_opcode = @import("opcodes.zig").decode_opcode;
const get_bit_at = @import("bitutils.zig").get_bit_at;
const OpInfo = @import("opcodes.zig").OpInfo;
const OperandInfo = @import("operand.zig").OperandInfo;
const get_operand = @import("operand.zig").get_operand;


const RESET_VECTOR = 0xFFFC;
const IRQ_VECTOR = 0xFFFE;
const NMI_VECTOR = 0xFFFA;

const STACK_BASE_POINTER: u16 = 0x100;

pub const StatusFlag = enum(u3) {
    CARRY,
    ZERO,
    INTERRUPT,
    DECIMAL,
    BREAK,
    UNUSED,
    OVERFLOW,
    NEGATIVE,
};


pub fn print_disassembly(cpu: *CPU, instruction: OpInfo, operand_info: OperandInfo) void {
  
    switch (instruction.addressing_mode) {
        .ABSOLUTE => std.debug.print("{X:0>4}:  {s} ${X:0>4}\n", .{cpu.PC, instruction.op_name, operand_info.address}),
        .ABSOLUTE_X => std.debug.print("{X:0>4}:  {s} ${X:0>4},X\n", .{cpu.PC, instruction.op_name, cpu.bus.read_16(cpu.PC+1)}),
        .ABSOLUTE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>4},Y\n", .{cpu.PC, instruction.op_name, cpu.bus.read_16(cpu.PC+1)}),
        .IMPLIED, .ACCUMULATOR => std.debug.print("{X:0>4}:  {s}\n", .{cpu.PC, instruction.op_name}),
        .INDIRECT => std.debug.print("{X:0>4}:  {s} (${X:0>4})\n", .{cpu.PC, instruction.op_name, cpu.bus.read_16(cpu.PC+1)}),
        .INDIRECT_Y => std.debug.print("{X:0>4}:  {s} (${X:0>2}),Y\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),
        .INDIRECT_X => std.debug.print("{X:0>4}:  {s} (${X:0>2},X)\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),
        .IMMEDIATE => std.debug.print("{X:0>4}:  {s} #${X:0>2}\n", .{cpu.PC, instruction.op_name, operand_info.operand}),
        .ZEROPAGE => std.debug.print("{X:0>4}:  {s} ${X:0>2}\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),
        .ZEROPAGE_Y => std.debug.print("{X:0>4}:  {s} ${X:0>2},Y\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),
        .ZEROPAGE_X => std.debug.print("{X:0>4}:  {s} ${X:0>2},X\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),
        .RELATIVE => std.debug.print("{X:0>4}:  {s} ${X:0>2}\n", .{cpu.PC, instruction.op_name, cpu.bus.read(cpu.PC+1)}),        
    }
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
    cycle_count: usize = 0,
    _wait_cycles: usize = 0,
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
        std.log.info("Loaded PC from reset vector: 0x{x:0>4}\n", .{self.PC});
    }


    pub fn irq(self: *CPU) void {
        if (self.get_status_flag(StatusFlag.INTERRUPT) == 1) {
            self.push_16(self.PC);
            self.status = bitutils.set_bit_at(self.status, StatusFlag.UNUSED, 0);
            self.push(self.status);

            self.PC = self.bus.read_16(IRQ_VECTOR);
        }
    }

    pub fn nmi(self: *CPU) void {
        self.push_16(self.PC);
        self.status = bitutils.set_bit_at(self.status, StatusFlag.UNUSED, 0);
        self.push(self.status);
        self.PC = self.bus.read_16(NMI_VECTOR);
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
        return self.bus.read(STACK_BASE_POINTER + self.SP);
    }


    pub fn pop_16(self: *CPU) u16 {
        const low_byte = @as(u16, self.pop());
        const high_byte = @as(u16, self.pop());
        return (high_byte << 8) | low_byte;
    }


    pub fn push(self: *CPU, val: u8) void {
        self.bus.write(STACK_BASE_POINTER + self.SP, val);
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
        const low_byte: u8 = @intCast((addr & 0x00FF));
        const high_byte: u8 = @intCast((addr >> 8));
        self.bus.write(RESET_VECTOR, low_byte);
        self.bus.write(RESET_VECTOR+1, high_byte);
    }
    
    pub fn print_stack(self: *CPU, limit: usize) void {
        var sp_abs = STACK_BASE_POINTER + @as(u16, self.SP) + 1;
        var count: usize = 0;
        std.debug.print("STACK:\n", .{});
        while (sp_abs <= STACK_BASE_POINTER + 0xFF and count < limit) {
            std.debug.print("{x:0>4}: {x:0>2}\n", .{sp_abs, self.bus.read(sp_abs)});
            sp_abs+=1;
            count+=1;
        }

    }

    pub fn clock_tick(self: *CPU) void {
      
        if(self.print_debug_info) {
            std.debug.print("==========================================================================================================================\n", .{});
            std.debug.print("Clock Tick {} {}!\n", .{self.cycle_count, self._wait_cycles});
            //std.debug.print("Reading instruction at 0x{x:0>4}\n", .{self.PC});
        }

        const opcode = self.fetch_byte();
        const instruction = decode_opcode(opcode);
        
        if(self.print_debug_info) {
            //std.debug.print("Loaded opcode 0x{x:0>2}\n", .{opcode});
            //std.debug.print("Instruction fetched ", .{});
            const operand_info = get_operand(self, instruction);
            print_disassembly(self, instruction, operand_info);
            instruction.print();
            operand_info.print();
        }
        
        instruction.handler_fn(self, instruction);
        
        self.cycle_count += 1;

        if(self.halt) {
            return;
        }
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
        std.debug.print("\n{} {} {} {} {} {} {} {} ", 
            .{ self.get_status_bit(7), 
                    self.get_status_bit(6), 
                    self.get_status_bit(5), 
                    self.get_status_bit(4), 
                    self.get_status_bit(3), 
                    self.get_status_bit(2), 
                    self.get_status_bit(1), 
                    self.get_status_bit(0) 
                });

        std.debug.print("\n----------------------------------------------------\n\n", .{});
    }
};

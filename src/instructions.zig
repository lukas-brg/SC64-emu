const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const InstructionStruct = @import("opcodes.zig").InstructionStruct;


inline fn combine_bytes(low: u8, high: u8) u16 {
    return low | (@as(u16, high) << 8);
}

inline fn get_bit_at(byte: u8, bit_index: u3) u1 {
    return @intCast((byte >> bit_index) & 1);
}

pub fn get_operand(cpu: *CPU, instruction: InstructionStruct) u8 {

    const address: u16 = switch (instruction.addressing_mode) {
        .IMMEDIATE => cpu.PC + 1,
        .ABSOLUTE => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)),
        .ABSOLUTE_X => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)) + cpu.X,
        .ABSOLUTE_Y => combine_bytes(cpu.bus.read(cpu.PC+1), cpu.bus.read(cpu.PC+2)) + cpu.Y,
        .ZEROPAGE => @as(u16, cpu.bus.read(cpu.PC+1)),
        .ZEROPAGE_X => @as(u16, cpu.bus.read(cpu.PC+1)) + cpu.X,
        .ZEROPAGE_Y => @as(u16, cpu.bus.read(cpu.PC+1)) + cpu.Y,
        .RELATIVE => cpu.PC + instruction.bytes + @as(u16, cpu.bus.read(cpu.PC + 1)),
        .INDIRECT => blk: {
            const lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            const addr = cpu.bus.read(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_X => blk: {
            var lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            lookup_addr += cpu.X;
            const addr = cpu.bus.read(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_Y => blk: {
            const lookup_addr = combine_bytes(cpu.bus.read(cpu.PC + 1), cpu.bus.read(cpu.PC+2));
            const addr = cpu.bus.read(lookup_addr) + cpu.Y;
            break :blk addr;
        },
        .IMPLIED => 0,
        .ACCUMULATOR => 0,
   
    };

    std.debug.print("Instruction ", .{});
    instruction.print();
    std.debug.print("address {}\n", .{address});

    const operand = switch (instruction.addressing_mode) {
        .IMPLIED => 0,
        .ACCUMULATOR => cpu.A,
        else => cpu.bus.read(address)
    };

    std.debug.print("operand {}\n", .{operand});
    return operand;
}


pub fn adc(cpu: *CPU, instruction: InstructionStruct) void {
    const operand = get_operand(cpu, instruction);
    const a_operand = cpu.A;                                                 
    const result = @addWithOverflow(cpu.A, operand + cpu.get_status_flag(StatusFlag.CARRY));
    cpu.A = result[0];
    cpu.set_status_flag(StatusFlag.CARRY, result[1]);
    
    if (cpu.A == 0) {
        cpu.set_status_flag(StatusFlag.ZERO, 1);
    } 
    else {
        cpu.set_status_flag(StatusFlag.ZERO, 0);
    }

    cpu.set_status_flag(StatusFlag.NEGATIVE, get_bit_at(cpu.A, 7));
    const v_flag: u1  = @intCast((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80);
    cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);

}


pub fn dummy(cpu: *CPU, instruction: InstructionStruct) void {
    // This function is called for every instruction that is not implemented yet
    const operand = get_operand(cpu, instruction);
    std.debug.print("dummy called\n", .{});
    instruction.print();
    _ = operand;
}
const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpInfo = @import("opcodes.zig").OpInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const get_operand = @import("operand.zig").get_operand;
const combine_bytes = @import("bitutils.zig").combine_bytes;
const get_bit_at = @import("bitutils.zig").get_bit_at;
const set_bit_at = @import("bitutils.zig").set_bit_at;
const bitutils = @import("bitutils.zig");
const DEBUG_CPU = @import("cpu.zig").DEBUG_CPU;





// ============================= INSTRUCTION IMPLEMENTATIONS ===========================================


pub fn adc(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const operand = operand_info.operand;
    
    const a_operand = cpu.A;                                                 
    const result_carry = @addWithOverflow(cpu.A, operand + cpu.get_status_flag(StatusFlag.CARRY));
    cpu.A = result_carry[0];
    
    cpu.set_status_flag(StatusFlag.CARRY, result_carry[1]);
    
    cpu.update_zero(cpu.A);
    cpu.update_negative(cpu.A);
    
    const v_flag: u1  = @intCast(((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80) >> 7);
    cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);
    cpu.PC += instruction.bytes;

    cpu._wait_cycles += operand_info.cycles;
}


// Zig won't let me use 'and' as a function name, hence the inconsistent naming
pub fn and_fn(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    cpu.A &= operand_info.operand;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;

    cpu._wait_cycles += operand_info.cycles;
}


pub fn asl(cpu: *CPU, instruction: OpInfo) void {
    var result: u8 = undefined;
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => {
            result = cpu.A << 1;
            cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(cpu.A, 7));
            cpu.A = result;
            cpu._wait_cycles += instruction.cycles;
        },
        else  => {
            const operand_info = get_operand(cpu, instruction);
            result = operand_info.operand << 1;
            cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(operand_info.operand, 7));
            cpu.bus.write(operand_info.address, result);
            cpu._wait_cycles += operand_info.cycles;
        }
    }

    cpu.update_negative(result);
    cpu.update_zero(result);
    
    cpu.PC += instruction.bytes;
}


pub fn bcc(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 1) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bcs(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 0) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn beq(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 1) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bmi(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 1) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bne(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 0) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bpl(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 0) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvc(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 0) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvs(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 1) {
        const operand_info = get_operand(cpu, instruction);
        cpu.PC = operand_info.address;
        cpu._wait_cycles += operand_info.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}



pub fn brk(cpu: *CPU, instruction: OpInfo) void {
    cpu.push_16(cpu.PC + 2);
    cpu.set_status_flag(StatusFlag.INTERRUPT, 1);
    
    const status_byte = bitutils.set_bit_at(cpu.status, @intFromEnum(StatusFlag.BREAK), 1);
    cpu.push(status_byte);
    
    cpu._wait_cycles += instruction.cycles;

    //cpu.PC += instruction.bytes;
    cpu.PC = cpu.bus.read_16(0xFFFE);
    //cpu.halt = true;
}

pub fn bit(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const operand = operand_info.operand;
    cpu.set_status_flag(StatusFlag.NEGATIVE, bitutils.get_bit_at(operand, 7));
    cpu.set_status_flag(StatusFlag.OVERFLOW, bitutils.get_bit_at(operand, 6));
    cpu.A &= operand;
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn clc(cpu: *CPU, instruction: OpInfo) void {
    cpu.set_status_flag(StatusFlag.CARRY, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn cld(cpu: *CPU, instruction: OpInfo) void {
    cpu.set_status_flag(StatusFlag.DECIMAL, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn cli(cpu: *CPU, instruction: OpInfo) void {
    cpu.set_status_flag(StatusFlag.INTERRUPT, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn clv(cpu: *CPU, instruction: OpInfo) void {
    cpu.set_status_flag(StatusFlag.OVERFLOW, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn cmp(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const result_carry = @subWithOverflow(cpu.A, operand_info.operand);
    const result = result_carry[0];
    const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, carry);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn cpx(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const result_carry = @subWithOverflow(cpu.X, operand_info.operand);
    const result = result_carry[0];
    const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, carry);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn cpy(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const result_carry = @subWithOverflow(cpu.Y, operand_info.operand);
    const result = result_carry[0];
    const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, carry);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dec(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    
    const result = operand_info.operand -% 1;
    cpu.bus.write(operand_info.address, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dex(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.X -% 1;
    
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dey(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.Y -% 1;
    cpu.Y = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn eor(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    
    const result = operand_info.operand ^ cpu.A;
    cpu.A = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn inc(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    
    const result = operand_info.operand +% 1;
    cpu.bus.write(operand_info.address, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn inx(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.X +% 1;
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn iny(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.Y +% 1;
    cpu.Y = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn jmp(cpu: *CPU, instruction: OpInfo) void {  
    const operand = get_operand(cpu, instruction);
    std.debug.print("{} {x}\n", .{instruction.addressing_mode, cpu.bus.read(cpu.PC+1)});
    cpu.PC = operand.address;
    cpu._wait_cycles += operand.cycles;
}

pub fn jsr(cpu: *CPU, instruction: OpInfo) void {  
    const operand = get_operand(cpu, instruction);
    cpu.push_16(cpu.PC + 2);
    cpu.PC = operand.address;
    cpu._wait_cycles += operand.cycles;
}

pub fn lda(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.A = operand_info.operand;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
}

pub fn ldx(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.X = operand_info.operand;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
    cpu.update_negative( cpu.X);
    cpu.update_zero(cpu.X);
}

pub fn ldy(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.Y = operand_info.operand;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
    cpu.update_negative( cpu.Y);
    cpu.update_zero(cpu.Y);
}

pub fn lsr(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    const result = operand_info.operand >> 1;

    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(operand_info.address, result)
    }

    cpu.set_status_flag(StatusFlag.NEGATIVE, 0);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(operand_info.operand, 0));
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}

pub fn nop(cpu: *CPU, instruction: OpInfo) void {  
   cpu.PC += instruction.bytes;
   cpu._wait_cycles += instruction.cycles;
}

pub fn ora(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    
    const result = operand_info.operand | cpu.A;
    cpu.A = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn pha(cpu: *CPU, instruction: OpInfo) void {
    const accumulator = cpu.A;
    cpu.push(accumulator);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn php(cpu: *CPU, instruction: OpInfo) void {
    var status = cpu.status;

    status = set_bit_at(status, @intFromEnum(StatusFlag.BREAK), 1);
    status = set_bit_at(status, 5, 1);
    cpu.push(status);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn pla(cpu: *CPU, instruction: OpInfo) void {
    cpu.status = cpu.pop();
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn plp(cpu: *CPU, instruction: OpInfo) void {
    cpu.A = cpu.pop();

    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);

    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn ror(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    const result = bitutils.rotate_right(operand_info.operand, 1);

    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(result, 0));
    
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(operand_info.address, result)
    }
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}

pub fn rol(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    const result = bitutils.rotate_left(operand_info.operand, 1);

    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(result, 0));
    
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(operand_info.address, result)
    }
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}

pub fn rti(cpu: *CPU, instruction: OpInfo) void {  
    var status = cpu.pop();
    
    // Break and unused bit are supposed to be ignored, so they are set to the previous state of the cpu
    status = bitutils.set_bit_at(status, @intFromEnum(StatusFlag.BREAK), get_bit_at(cpu.status, @intFromEnum(StatusFlag.BREAK)));
    status = bitutils.set_bit_at(status, @intFromEnum(StatusFlag.UNUSED), get_bit_at(cpu.status, @intFromEnum(StatusFlag.UNUSED)));
    cpu.status = status;
    cpu.PC = cpu.pop_16();
    cpu._wait_cycles += instruction.cycles;
}


pub fn rts(cpu: *CPU, instruction: OpInfo) void {  
    cpu.PC = cpu.pop_16() + 1;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sbc(cpu: *CPU, instruction: OpInfo) void {
    const operand_info = get_operand(cpu, instruction);
    const operand = operand_info.operand;
    
    const a_operand = cpu.A;                                                 
    const result_carry = @subWithOverflow(cpu.A, operand - cpu.get_status_flag(StatusFlag.CARRY));
    cpu.A = result_carry[0];
    
    cpu.set_status_flag(StatusFlag.CARRY, result_carry[1]);
    
    cpu.update_zero(cpu.A);
    cpu.update_negative(cpu.A);
    
    const v_flag: u1  = @intCast(((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80) >> 7);
    cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);
    cpu.PC += instruction.bytes;

    cpu._wait_cycles += operand_info.cycles;
}


pub fn sec(cpu: *CPU, instruction: OpInfo) void {  
    cpu.set_status_flag(StatusFlag.CARRY, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sed(cpu: *CPU, instruction: OpInfo) void {  
    cpu.set_status_flag(StatusFlag.DECIMAL, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn sei(cpu: *CPU, instruction: OpInfo) void {  
    cpu.set_status_flag(StatusFlag.INTERRUPT, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sta(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.bus.write(operand_info.address, cpu.A);
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}

pub fn stx(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.bus.write(operand_info.address, cpu.X);
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}



pub fn sty(cpu: *CPU, instruction: OpInfo) void {  
    const operand_info = get_operand(cpu, instruction);
    cpu.bus.write(operand_info.address, cpu.Y);
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += operand_info.cycles;
}


pub fn tax(cpu: *CPU, instruction: OpInfo) void {  
    cpu.X = cpu.A;
    cpu.update_negative(cpu.X);
    cpu.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn tay(cpu: *CPU, instruction: OpInfo) void {  
    cpu.Y = cpu.A;
    cpu.update_negative(cpu.Y);
    cpu.update_zero(cpu.Y);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn tsx(cpu: *CPU, instruction: OpInfo) void {  
    cpu.X = cpu.SP;
    cpu.update_negative(cpu.X);
    cpu.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn txa(cpu: *CPU, instruction: OpInfo) void {  
    cpu.A = cpu.X;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn txs(cpu: *CPU, instruction: OpInfo) void {  
    cpu.SP = cpu.X;
    cpu.update_negative(cpu.SP);
    cpu.update_zero(cpu.SP);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn tya(cpu: *CPU, instruction: OpInfo) void {  
    cpu.A = cpu.Y;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dummy(cpu: *CPU, instruction: OpInfo) void {
    // This function is called for every instruction that is not implemented yet
    const operand_info = get_operand(cpu, instruction);

    _ = operand_info;
}
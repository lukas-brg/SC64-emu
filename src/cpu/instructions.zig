const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpInfo = @import("opcodes.zig").OpInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const get_operand = @import("operand.zig").get_operand;
const combine_bytes = @import("bitutils.zig").combine_bytes;
const get_bit_at = @import("bitutils.zig").get_bit_at;

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
    
    const v_flag: u1  = @intCast((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80);
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
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bcs(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 0) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn beq(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 1) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bmi(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 1) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bne(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 0) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bpl(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 0) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvc(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 0) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvs(cpu: *CPU, instruction: OpInfo) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 1) {
        const operand = get_operand(cpu, instruction);
        cpu.PC = operand.address;
        cpu._wait_cycles += operand.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}



pub fn brk(cpu: *CPU, instruction: OpInfo) void {
    cpu.push_16(cpu.PC + 2);
    
    cpu._wait_cycles += instruction.cycles;

    cpu.set_status_flag(StatusFlag.INTERRUPT, 1);
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
    
    const result = operand_info.operand - 1;
    cpu.bus.write(operand_info.address, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dex(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.X - 1;
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dey(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.Y - 1;
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
    
    const result = operand_info.operand + 1;
    cpu.bus.write(operand_info.address, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn inx(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.X + 1;
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn iny(cpu: *CPU, instruction: OpInfo) void {
    const result = cpu.Y + 1;
    cpu.Y = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn jmp(cpu: *CPU, instruction: OpInfo) void {  
    const operand = get_operand(cpu, instruction);
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


pub fn dummy(cpu: *CPU, instruction: OpInfo) void {
    // This function is called for every instruction that is not implemented yet
    const operand_info = get_operand(cpu, instruction);

    _ = operand_info;
}
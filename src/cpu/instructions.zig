const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const Instruction = @import("instruction.zig").Instruction;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const combyne_bytes = @import("bitutils.zig").combine_bytes;
const get_bit_at = @import("bitutils.zig").get_bit_at;
const set_bit_at = @import("bitutils.zig").set_bit_at;
const bitutils = @import("bitutils.zig");
const DEBUG_CPU = @import("cpu.zig").self.pring_debug_info;





// ============================= INSTRUCTION IMPLEMENTATIONS ===========================================


pub fn adc(cpu: *CPU, instruction: Instruction) void {
    
    const operand = instruction.operand.?;
    
    const a_operand = cpu.A;                                                 
    
    if (cpu.get_status_flag(StatusFlag.DECIMAL) == 0) {
        
        const carry_in_add = @addWithOverflow(operand, cpu.get_status_flag(StatusFlag.CARRY));

        const result_carry = @addWithOverflow(cpu.A, carry_in_add[0]);
        cpu.A = result_carry[0];
        const carry_out: u1 = result_carry[1] | carry_in_add[1];
        cpu.set_status_flag(StatusFlag.CARRY, carry_out);
        cpu.update_negative(cpu.A);
        const v_flag: u1  = @intCast(((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80) >> 7);
        cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);

    } else {
        var AL = (cpu.A & 0xF) + (operand & 0xF) + cpu.get_status_flag(StatusFlag.CARRY);         
        var AH = (cpu.A >> 4) + (operand >> 4) + @intFromBool(AL > 15); 

        if (AL > 9) AL += 6;
        const N: u1 = @intFromBool(AH & 8 != 0);
        const V = @intFromBool(((((AH << 4) ^ cpu.A) & 0x80) != 0) and !(((cpu.A ^ operand) & 0x80) != 0));

        cpu.set_status_flag(StatusFlag.OVERFLOW, V);
        cpu.set_status_flag(StatusFlag.NEGATIVE, N);

        if (AH > 9) AH += 6; 
        const C: u1 = @intFromBool(AH > 15);
        cpu.set_status_flag(StatusFlag.CARRY, C);
        cpu.A = (AH << 4) | (AL & 0xF);
    }

    cpu.update_zero(cpu.A);

    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;    
}


// Zig won't let me use 'and' as a function name, hence the inconsistent naming
pub fn and_fn(cpu: *CPU, instruction: Instruction) void {
    
    cpu.A &= instruction.operand.?;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn asl(cpu: *CPU, instruction: Instruction) void {
    var result: u8 = undefined;
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => {
            result = cpu.A << 1;
            cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(cpu.A, 7));
            cpu.A = result;
            cpu._wait_cycles += instruction.cycles;
        },
        else  => {
            
            result = instruction.operand.? << 1;
            cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(instruction.operand.?, 7));
            cpu.bus.write(instruction.operand_addr.?, result);
            cpu._wait_cycles += instruction.cycles;
        }
    }

    cpu.update_negative(result);
    cpu.update_zero(result);
    
    cpu.PC += instruction.bytes;
}


pub fn bcc(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 0) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bcs(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.CARRY) == 1) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn beq(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 1) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bmi(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 1) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bne(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.ZERO) == 0) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}

pub fn bpl(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.NEGATIVE) == 0) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvc(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 0) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn bvs(cpu: *CPU, instruction: Instruction) void {
    if (cpu.get_status_flag(StatusFlag.OVERFLOW) == 1) {
        
        cpu.PC = instruction.operand_addr.?;
        cpu._wait_cycles += instruction.cycles;
    }
    else {
        cpu.PC += instruction.bytes;
        cpu._wait_cycles += instruction.cycles;
    }
}


pub fn brk(cpu: *CPU, instruction: Instruction) void {
    cpu.push_16(cpu.PC + 2);
    
    var status_byte = bitutils.set_bit_at(cpu.status, @intFromEnum(StatusFlag.BREAK), 1);
    status_byte = bitutils.set_bit_at(status_byte, @intFromEnum(StatusFlag.UNUSED), 1);
    cpu.push(status_byte);
    cpu.set_status_flag(StatusFlag.INTERRUPT_DISABLE, 1);
    
    cpu._wait_cycles += instruction.cycles;

    //cpu.PC += instruction.bytes;
    cpu.PC = cpu.bus.read_16(0xFFFE);
    //cpu.halt = true;
}


pub fn bit(cpu: *CPU, instruction: Instruction) void {
    const operand = instruction.operand.?;
    cpu.set_status_flag(StatusFlag.NEGATIVE, bitutils.get_bit_at(operand, 7));
    cpu.set_status_flag(StatusFlag.OVERFLOW, bitutils.get_bit_at(operand, 6));
    cpu.update_zero(operand & cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn clc(cpu: *CPU, instruction: Instruction) void {
    cpu.set_status_flag(StatusFlag.CARRY, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn cld(cpu: *CPU, instruction: Instruction) void {
    cpu.set_status_flag(StatusFlag.DECIMAL, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn cli(cpu: *CPU, instruction: Instruction) void {
    cpu.set_status_flag(StatusFlag.INTERRUPT_DISABLE, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn clv(cpu: *CPU, instruction: Instruction) void {
    cpu.set_status_flag(StatusFlag.OVERFLOW, 0);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn cmp(cpu: *CPU, instruction: Instruction) void {
    
    const result_carry = @subWithOverflow(cpu.A, instruction.operand.?);
    const result = result_carry[0];
    //const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    const carry_flag: u1 = cpu.get_status_flag(StatusFlag.NEGATIVE) ^ 1;
    cpu.set_status_flag(StatusFlag.CARRY, carry_flag);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn cpx(cpu: *CPU, instruction: Instruction) void {
    
    const result_carry = @subWithOverflow(cpu.X, instruction.operand.?);
    const result = result_carry[0];
    //const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    const carry_flag: u1 = cpu.get_status_flag(StatusFlag.NEGATIVE) ^ 1;
    cpu.set_status_flag(StatusFlag.CARRY, carry_flag);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn cpy(cpu: *CPU, instruction: Instruction) void {
    
    const result_carry = @subWithOverflow(cpu.Y, instruction.operand.?);
    const result = result_carry[0];
    //const carry = result_carry[1];
    
    cpu.update_negative(result);
    cpu.update_zero(result);
    const carry_flag: u1 = cpu.get_status_flag(StatusFlag.NEGATIVE) ^ 1;
    cpu.set_status_flag(StatusFlag.CARRY, carry_flag);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dec(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? -% 1;
    cpu.bus.write(instruction.operand_addr.?, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dex(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.X -% 1;
    
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dey(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.Y -% 1;
    cpu.Y = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn eor(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? ^ cpu.A;
    cpu.A = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn inc(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? +% 1;
    cpu.bus.write(instruction.operand_addr.?, result);
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn inx(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.X +% 1;
    cpu.X = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn iny(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.Y +% 1;
    cpu.Y = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn jmp(cpu: *CPU, instruction: Instruction) void {
    cpu.PC = instruction.operand_addr.?;
    cpu._wait_cycles += instruction.cycles;
}

pub fn jsr(cpu: *CPU, instruction: Instruction) void {
    cpu.push_16(cpu.PC + 2);
    cpu.PC = instruction.operand_addr.?;
    cpu._wait_cycles += instruction.cycles;
}

pub fn lda(cpu: *CPU, instruction: Instruction) void {  
    cpu.A = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
}

pub fn ldx(cpu: *CPU, instruction: Instruction) void {  
    cpu.X = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
    cpu.update_negative( cpu.X);
    cpu.update_zero(cpu.X);
}

pub fn ldy(cpu: *CPU, instruction: Instruction) void {  
    
    cpu.Y = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
    cpu.update_negative( cpu.Y);
    cpu.update_zero(cpu.Y);
}

pub fn lsr(cpu: *CPU, instruction: Instruction) void {  
    
    const result = instruction.operand.? >> 1;

    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result)
    }

    cpu.set_status_flag(StatusFlag.NEGATIVE, 0);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(instruction.operand.?, 0));
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn nop(cpu: *CPU, instruction: Instruction) void {  
   cpu.PC += instruction.bytes;
   cpu._wait_cycles += instruction.cycles;
}

pub fn ora(cpu: *CPU, instruction: Instruction) void {
    
    const result = instruction.operand.? | cpu.A;
    cpu.A = result;
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn pha(cpu: *CPU, instruction: Instruction) void {
    const accumulator = cpu.A;
    cpu.push(accumulator);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn php(cpu: *CPU, instruction: Instruction) void {
    var status = cpu.status;

    status = set_bit_at(status, @intFromEnum(StatusFlag.BREAK), 1);
    status = set_bit_at(status, 5, 1);
    cpu.push(status);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn pla(cpu: *CPU, instruction: Instruction) void {
    cpu.A = cpu.pop();
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn plp(cpu: *CPU, instruction: Instruction) void {
    var status = cpu.pop();
    status = set_bit_at(status, @intFromEnum(StatusFlag.BREAK), 1);
    status = set_bit_at(status, 5, 1);
    cpu.status = status;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;

}


pub fn ror(cpu: *CPU, instruction: Instruction) void {  
    
    var result = bitutils.rotate_right(instruction.operand.?, 1);
    result = bitutils.set_bit_at(result,  7, cpu.get_status_flag(StatusFlag.CARRY));
    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(instruction.operand.?, 0));
    
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result)
    }
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn rol(cpu: *CPU, instruction: Instruction) void {  
    
    var result = bitutils.rotate_left(instruction.operand.?, 1);
    result = bitutils.set_bit_at(result,  0, cpu.get_status_flag(StatusFlag.CARRY));

    cpu.update_negative(result);
    cpu.update_zero(result);
    cpu.set_status_flag(StatusFlag.CARRY, get_bit_at(instruction.operand.?, 7));
    
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result)
    }
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn rti(cpu: *CPU, instruction: Instruction) void {  
    var status = cpu.pop();
    
    // Break and unused bit are supposed to be ignored, so they are set to the previous state of the cpu
    status = bitutils.set_bit_at(
        status,
    @intFromEnum(StatusFlag.BREAK),
       get_bit_at(cpu.status, @intFromEnum(StatusFlag.BREAK))
    );
    
    status = bitutils.set_bit_at(
        status,
     @intFromEnum(StatusFlag.UNUSED),
     get_bit_at(cpu.status, @intFromEnum(StatusFlag.UNUSED))
     );
    
    cpu.status = status;
    cpu.PC = cpu.pop_16();
    cpu._wait_cycles += instruction.cycles;
}


pub fn rts(cpu: *CPU, instruction: Instruction) void {  
    cpu.PC = cpu.pop_16() + 1;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sbc(cpu: *CPU, instruction: Instruction) void {
    
    const a_operand = cpu.A;       

    if(cpu.get_status_flag(StatusFlag.DECIMAL) == 0) {
        //SBC in binary mode is just ADC with the second operand negated
        const operand = ~instruction.operand.?;
        const carry_in_add = @addWithOverflow(operand, cpu.get_status_flag(StatusFlag.CARRY));

        const result_carry = @addWithOverflow(cpu.A, carry_in_add[0]);
        cpu.A = result_carry[0];
        const carry_out: u1 = result_carry[1] | carry_in_add[1];
        cpu.set_status_flag(StatusFlag.CARRY, carry_out);
        cpu.update_negative(cpu.A);
        const v_flag: u1  = @intCast(((a_operand ^ cpu.A) & (operand ^ cpu.A) & 0x80) >> 7);
        cpu.set_status_flag(StatusFlag.OVERFLOW, v_flag);
        cpu.update_zero(cpu.A);
    } 
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;    
}


pub fn sec(cpu: *CPU, instruction: Instruction) void {  
    cpu.set_status_flag(StatusFlag.CARRY, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sed(cpu: *CPU, instruction: Instruction) void {  
    cpu.set_status_flag(StatusFlag.DECIMAL, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn sei(cpu: *CPU, instruction: Instruction) void {  
    cpu.set_status_flag(StatusFlag.INTERRUPT_DISABLE, 1);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn sta(cpu: *CPU, instruction: Instruction) void {  
    
    cpu.bus.write(instruction.operand_addr.?, cpu.A);
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn stx(cpu: *CPU, instruction: Instruction) void {  
    
    cpu.bus.write(instruction.operand_addr.?, cpu.X);
    
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}



pub fn sty(cpu: *CPU, instruction: Instruction) void {  
    cpu.bus.write(instruction.operand_addr.?, cpu.Y);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn tax(cpu: *CPU, instruction: Instruction) void {  
    cpu.X = cpu.A;
    cpu.update_negative(cpu.X);
    cpu.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn tay(cpu: *CPU, instruction: Instruction) void {  
    cpu.Y = cpu.A;
    cpu.update_negative(cpu.Y);
    cpu.update_zero(cpu.Y);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn tsx(cpu: *CPU, instruction: Instruction) void {  
    cpu.X = cpu.SP;
    cpu.update_negative(cpu.X);
    cpu.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}

pub fn txa(cpu: *CPU, instruction: Instruction) void {  
    cpu.A = cpu.X;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn txs(cpu: *CPU, instruction: Instruction) void {  
    cpu.SP = cpu.X;
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn tya(cpu: *CPU, instruction: Instruction) void {  
    cpu.A = cpu.Y;
    cpu.update_negative(cpu.A);
    cpu.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu._wait_cycles += instruction.cycles;
}


pub fn dummy(cpu: *CPU, instruction: Instruction) void {
    // This function is called for every instruction that is not implemented yet
    _ = cpu;
    _ = instruction;
}
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


    if (cpu.status.decimal == 0) {
    
        const result = cpu.A +% operand +% cpu.status.carry;

        cpu.status.carry = @intFromBool(bitutils.did_carry_out_of_bit(cpu.A, operand, result, 7));
        cpu.status.update_negative(result);
        const v_flag: u1 = @intCast(((cpu.A ^ result) & (operand ^ result) & 0x80) >> 7);
        cpu.status.overflow = v_flag;
        cpu.status.update_zero(result);
        cpu.A = result;

    } else {
        const c_in = cpu.status.carry;
        const binres =  cpu.A +% operand +% c_in;
        var c_out = @intFromBool(bitutils.did_carry_out_of_bit(cpu.A, operand, binres, 7));

        var decres = binres;
        if (bitutils.did_carry_into_bit(cpu.A, operand, binres, 4)) {
            decres = (decres & 0xf0) | ((decres +% 0x06) & 0x0f);
        } else if ((decres & 0xf) > 0x9) {
            c_out |= @intFromBool(decres >= (0x100 - 0x6));
            decres +%= 0x06;
        }
        cpu.status.update_negative(decres);

        //const v_flag: u1 = @intFromBool(((((decres ^ cpu.A) & (decres ^ operand) ) & 0x80) >> 1) > 0);
        const v_flag: u1 = @intCast((((decres ^ cpu.A) & (decres ^ operand)) & 0x80) >> 7);
        cpu.status.overflow = v_flag;
        c_out |= @intFromBool(decres >= 0xa0);
        cpu.status.carry = c_out;

        if (c_out == 1) {
            decres +%= 0x60;
        }
        cpu.A = decres;
    }

    cpu.status.update_zero(cpu.A);

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

// Zig won't let me use 'and' as a function name, hence the inconsistent naming
pub fn and_fn(cpu: *CPU, instruction: Instruction) void {
    cpu.A &= instruction.operand.?;
    cpu.status.update_negative(cpu.A);
    cpu.status.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn asl(cpu: *CPU, instruction: Instruction) void {
    var result: u8 = undefined;
    switch (instruction.addressing_mode) {
        .ACCUMULATOR => {
            result = cpu.A << 1;
            cpu.status.carry = bitutils.get_bit_at(cpu.A, 7);
            cpu.A = result;
            cpu.instruction_remaining_cycles += instruction.cycles;
        },
        else => {
            result = instruction.operand.? << 1;
            cpu.status.carry = bitutils.get_bit_at(instruction.operand.?, 7);
            cpu.bus.write(instruction.operand_addr.?, result);
            cpu.instruction_remaining_cycles += instruction.cycles;
        },
    }

    cpu.status.update_negative(result);
    cpu.status.update_zero(result);

    cpu.PC += instruction.bytes;
}

pub fn bcc(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.carry == 0) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bcs(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.carry == 1) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn beq(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.zero == 1) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bmi(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.negative == 1) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bne(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.zero == 0) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bpl(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.negative == 0) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bvc(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.overflow == 0) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn bvs(cpu: *CPU, instruction: Instruction) void {
    if (cpu.status.overflow == 1) {
        cpu.PC = instruction.operand_addr.?;
        cpu.instruction_remaining_cycles += instruction.cycles;
    } else {
        cpu.PC += instruction.bytes;
        cpu.instruction_remaining_cycles += instruction.cycles;
    }
}

pub fn brk(cpu: *CPU, instruction: Instruction) void {
    cpu.push_16(cpu.PC + 2);
    var status = cpu.status;
    status.break_flag = 1;
    cpu.push(status.to_byte());
    cpu.status.interrupt_disable = 1;
    cpu.instruction_remaining_cycles += instruction.cycles;
    cpu.PC = cpu.bus.read_16(0xFFFE);
}

pub fn bit(cpu: *CPU, instruction: Instruction) void {
    const operand = instruction.operand.?;
    cpu.status.negative = bitutils.get_bit_at(operand, 7);
    
    cpu.status.overflow = bitutils.get_bit_at(operand, 6);
    cpu.status.update_zero(operand & cpu.A);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn clc(cpu: *CPU, instruction: Instruction) void {
    cpu.status.carry = 0;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn cld(cpu: *CPU, instruction: Instruction) void {
    cpu.status.decimal = 0;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn cli(cpu: *CPU, instruction: Instruction) void {
    cpu.status.interrupt_disable = 0;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn clv(cpu: *CPU, instruction: Instruction) void {
    cpu.status.overflow = 0;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn cmp(cpu: *CPU, instruction: Instruction) void {
    const operand = instruction.operand.?;
    const result = cpu.A -% operand;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.status.carry = @intFromBool(cpu.A >= operand);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn cpx(cpu: *CPU, instruction: Instruction) void {
    const operand = instruction.operand.?;
    const result = cpu.X -% operand;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.status.carry = @intFromBool(cpu.X >= operand);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn cpy(cpu: *CPU, instruction: Instruction) void {
    const operand = instruction.operand.?;
    const result = cpu.Y -% operand;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.status.carry = @intFromBool(cpu.Y >= operand);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn dec(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? -% 1;
    cpu.bus.write(instruction.operand_addr.?, result);
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn dex(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.X -% 1;

    cpu.X = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn dey(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.Y -% 1;
    cpu.Y = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn eor(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? ^ cpu.A;
    cpu.A = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn inc(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? +% 1;
    cpu.bus.write(instruction.operand_addr.?, result);
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn inx(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.X +% 1;
    cpu.X = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn iny(cpu: *CPU, instruction: Instruction) void {
    const result = cpu.Y +% 1;
    cpu.Y = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn jmp(cpu: *CPU, instruction: Instruction) void {
    cpu.PC = instruction.operand_addr.?;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn jsr(cpu: *CPU, instruction: Instruction) void {
    cpu.push_16(cpu.PC + 2);
    cpu.PC = instruction.operand_addr.?;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn lda(cpu: *CPU, instruction: Instruction) void {
    cpu.A = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
    cpu.status.update_negative(cpu.A);
    cpu.status.update_zero(cpu.A);
}

pub fn ldx(cpu: *CPU, instruction: Instruction) void {
    cpu.X = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
    cpu.status.update_negative(cpu.X);
    cpu.status.update_zero(cpu.X);
}

pub fn ldy(cpu: *CPU, instruction: Instruction) void {
    cpu.Y = instruction.operand.?;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
    cpu.status.update_negative(cpu.Y);
    cpu.status.update_zero(cpu.Y);
}

pub fn lsr(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? >> 1;

    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result),
    }

    cpu.status.negative = 0;
    cpu.status.update_zero(result);
    cpu.status.carry = get_bit_at(instruction.operand.?, 0);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn nop(cpu: *CPU, instruction: Instruction) void {
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn ora(cpu: *CPU, instruction: Instruction) void {
    const result = instruction.operand.? | cpu.A;
    cpu.A = result;
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn pha(cpu: *CPU, instruction: Instruction) void {
    const accumulator = cpu.A;
    cpu.push(accumulator);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn php(cpu: *CPU, instruction: Instruction) void {
    var status = cpu.status;
    status.break_flag = 1;
    status.unused = 1;
    cpu.push(status.to_byte());
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn pla(cpu: *CPU, instruction: Instruction) void {
    cpu.A = cpu.pop();
    cpu.status.update_negative(cpu.A);
    cpu.status.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn plp(cpu: *CPU, instruction: Instruction) void {
    cpu.status.update(cpu.pop());
    cpu.status.break_flag = 1;
    cpu.status.unused = 1;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn ror(cpu: *CPU, instruction: Instruction) void {
    var result = bitutils.rotate_right(instruction.operand.?, 1);
    result = bitutils.set_bit_at(result, 7, cpu.status.carry);
    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.status.carry = get_bit_at(instruction.operand.?, 0);

    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result),
    }

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn rol(cpu: *CPU, instruction: Instruction) void {
    var result = bitutils.rotate_left(instruction.operand.?, 1);
    result = bitutils.set_bit_at(result, 0, cpu.status.carry);

    cpu.status.update_negative(result);
    cpu.status.update_zero(result);
    cpu.status.carry = get_bit_at(instruction.operand.?, 7);

    switch (instruction.addressing_mode) {
        .ACCUMULATOR => cpu.A = result,
        else => cpu.bus.write(instruction.operand_addr.?, result),
    }

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn rti(cpu: *CPU, instruction: Instruction) void {
    cpu.status.update(cpu.pop());
    cpu.status.break_flag = 0;
    cpu.PC = cpu.pop_16();
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn rts(cpu: *CPU, instruction: Instruction) void {
    cpu.PC = cpu.pop_16() + 1;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sbc(cpu: *CPU, instruction: Instruction) void {

    if (cpu.status.decimal == 0) {
        const operand = ~instruction.operand.?;
        const result = cpu.A +% operand +% cpu.status.carry;

        cpu.status.carry = @intFromBool(bitutils.did_carry_out_of_bit(cpu.A, operand, result, 7));
        cpu.status.update_negative(result);
        const v_flag: u1 = @intCast(((cpu.A ^ result) & (operand ^ result) & 0x80) >> 7);
        cpu.status.overflow = v_flag;
        cpu.status.update_zero(result);
        cpu.A = result;
    } else {

        const operand: u8 = ~instruction.operand.?;
        const c_in = cpu.status.carry;
        const binres = cpu.A +% operand +% c_in; 

        var decres = binres;
        cpu.status.update_zero(binres);

        const c_out: u1 = @intFromBool(bitutils.did_carry_out_of_bit(cpu.A, operand, binres, 7));
        cpu.status.carry = c_out;
        cpu.status.update_negative(binres);
        const v_flag: u1 = @intCast(((((binres ^ cpu.A) & (binres ^ operand) ) & 0x80) >> 7));
        cpu.status.overflow = v_flag;
        if (!bitutils.did_carry_into_bit(cpu.A, operand, binres, 4)) {
            decres = (decres & 0xf0) | ((decres +% 0xfa) & 0xf);
        }        

        if (c_out == 0) {
            decres +%= 0xA0;
        }

        cpu.A = decres;
    }

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sec(cpu: *CPU, instruction: Instruction) void {
    cpu.status.carry = 1;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sed(cpu: *CPU, instruction: Instruction) void {
    cpu.status.decimal = 1;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sei(cpu: *CPU, instruction: Instruction) void {
    cpu.status.interrupt_disable = 1;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sta(cpu: *CPU, instruction: Instruction) void {
    cpu.bus.write(instruction.operand_addr.?, cpu.A);

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn stx(cpu: *CPU, instruction: Instruction) void {
    cpu.bus.write(instruction.operand_addr.?, cpu.X);

    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn sty(cpu: *CPU, instruction: Instruction) void {
    cpu.bus.write(instruction.operand_addr.?, cpu.Y);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn tax(cpu: *CPU, instruction: Instruction) void {
    cpu.X = cpu.A;
    cpu.status.update_negative(cpu.X);
    cpu.status.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn tay(cpu: *CPU, instruction: Instruction) void {
    cpu.Y = cpu.A;
    cpu.status.update_negative(cpu.Y);
    cpu.status.update_zero(cpu.Y);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn tsx(cpu: *CPU, instruction: Instruction) void {
    cpu.X = cpu.SP;
    cpu.status.update_negative(cpu.X);
    cpu.status.update_zero(cpu.X);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn txa(cpu: *CPU, instruction: Instruction) void {
    cpu.A = cpu.X;
    cpu.status.update_negative(cpu.A);
    cpu.status.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn txs(cpu: *CPU, instruction: Instruction) void {
    cpu.SP = cpu.X;
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn tya(cpu: *CPU, instruction: Instruction) void {
    cpu.A = cpu.Y;
    cpu.status.update_negative(cpu.A);
    cpu.status.update_zero(cpu.A);
    cpu.PC += instruction.bytes;
    cpu.instruction_remaining_cycles += instruction.cycles;
}

pub fn dummy(cpu: *CPU, instruction: Instruction) void {
    // This function is called for every instruction that is not implemented yet
    _ = cpu;
    _ = instruction;
}

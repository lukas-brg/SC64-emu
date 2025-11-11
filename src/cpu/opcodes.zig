const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const instructions = @import("instructions.zig");
const instruction = @import("instruction.zig");

const HandlerFn = fn(*CPU, *instruction.Instruction) void;


const opcode_lookup_table: [256]?OpcodeInfo = blk: {
    var table: [256]?OpcodeInfo = [_]?OpcodeInfo{null} ** 256;
    for (OPCODE_TABLE) |opcode_struct| {
        table[opcode_struct.opcode] = opcode_struct;
    }
    break :blk table;
};


pub inline fn decodeOpcode(opcode: u8) ?OpcodeInfo {
    return opcode_lookup_table[opcode];
}


pub const AddressingMode = enum {
    ACCUMULATOR,
    ABSOLUTE,
    ABSOLUTE_X,
    ABSOLUTE_Y,
    IMMEDIATE,
    IMPLIED,
    INDIRECT,
    INDIRECT_X,
    INDIRECT_Y,
    RELATIVE,
    ZEROPAGE,
    ZEROPAGE_X,
    ZEROPAGE_Y,
};


pub const OpcodeInfo = struct {
    opcode: u8,
    mnemonic: []const u8,
    addressing_mode: AddressingMode,
    bytes: u3,
    cycles: u4,
    handler_fn:  * const HandlerFn,

    pub fn print(self: OpcodeInfo) void {
        std.debug.print("(Name: {s}, Opcode: 0x{x:0>2},  Addressing Mode: {s}, Bytes: {}, Cycles: {})\n",
            .{self.mnemonic, self.opcode, @tagName(self.addressing_mode), self.bytes, self.cycles});
    }
};


const OPCODE_TABLE = [_]OpcodeInfo{
    // Only the legal opcodes are implemented for now, ToDo?
    .{.opcode=0x69, .mnemonic="ADC", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.adc},
    .{.opcode=0x65, .mnemonic="ADC", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.adc},
    .{.opcode=0x75, .mnemonic="ADC", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.adc},
    .{.opcode=0x6D, .mnemonic="ADC", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.adc},
    .{.opcode=0x7D, .mnemonic="ADC", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.adc},
    .{.opcode=0x79, .mnemonic="ADC", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.adc},
    .{.opcode=0x61, .mnemonic="ADC", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.adc},
    .{.opcode=0x71, .mnemonic="ADC", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.adc},
   
    .{.opcode=0x29, .mnemonic="AND", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.and_fn},
    .{.opcode=0x25, .mnemonic="AND", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.and_fn},
    .{.opcode=0x35, .mnemonic="AND", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.and_fn},
    .{.opcode=0x2D, .mnemonic="AND", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.and_fn},
    .{.opcode=0x3D, .mnemonic="AND", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.and_fn},
    .{.opcode=0x39, .mnemonic="AND", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.and_fn},
    .{.opcode=0x21, .mnemonic="AND", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.and_fn},
    .{.opcode=0x31, .mnemonic="AND", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.and_fn},
   
    .{.opcode=0x0A, .mnemonic="ASL", .addressing_mode=.ACCUMULATOR,.bytes = 1, .cycles = 2, .handler_fn = instructions.asl},
    .{.opcode=0x06, .mnemonic="ASL", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.asl},
    .{.opcode=0x16, .mnemonic="ASL", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.asl},
    .{.opcode=0x0E, .mnemonic="ASL", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.asl},
    .{.opcode=0x1E, .mnemonic="ASL", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.asl},
  
    .{.opcode=0x90, .mnemonic="BCC", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bcc},
    .{.opcode=0xB0, .mnemonic="BCS", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bcs},
    .{.opcode=0xF0, .mnemonic="BEQ", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.beq},
    .{.opcode=0x30, .mnemonic="BMI", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bmi},
    .{.opcode=0xD0, .mnemonic="BNE", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bne},
    .{.opcode=0x10, .mnemonic="BPL", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bpl},
    .{.opcode=0x50, .mnemonic="BVC", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bvc},
    .{.opcode=0x70, .mnemonic="BVS", .addressing_mode=.RELATIVE,   .bytes = 2, .cycles = 2, .handler_fn = instructions.bvs},
   
    .{.opcode=0x24, .mnemonic="BIT", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.bit},
    .{.opcode=0x2C, .mnemonic="BIT", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.bit},
  
    .{.opcode=0x00, .mnemonic="BRK", .addressing_mode=.IMPLIED,    .bytes = 2, .cycles = 7, .handler_fn = instructions.brk},
  
    .{.opcode=0x18, .mnemonic="CLC", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.clc},
    .{.opcode=0xD8, .mnemonic="CLD", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.cld},
    .{.opcode=0x58, .mnemonic="CLI", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.cli},
    .{.opcode=0xB8, .mnemonic="CLV", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.clv},
   
    .{.opcode=0xC9, .mnemonic="CMP", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.cmp},
    .{.opcode=0xC5, .mnemonic="CMP", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.cmp},
    .{.opcode=0xD5, .mnemonic="CMP", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.cmp},
    .{.opcode=0xCD, .mnemonic="CMP", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.cmp},
    .{.opcode=0xDD, .mnemonic="CMP", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.cmp},
    .{.opcode=0xD9, .mnemonic="CMP", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.cmp},
    .{.opcode=0xC1, .mnemonic="CMP", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.cmp},
    .{.opcode=0xD1, .mnemonic="CMP", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.cmp},
  
    .{.opcode=0xE0, .mnemonic="CPX", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.cpx},
    .{.opcode=0xE4, .mnemonic="CPX", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.cpx},
    .{.opcode=0xEC, .mnemonic="CPX", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.cpx},
  
    .{.opcode=0xC0, .mnemonic="CPY", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.cpy},
    .{.opcode=0xC4, .mnemonic="CPY", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.cpy},
    .{.opcode=0xCC, .mnemonic="CPY", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.cpy},
  
    .{.opcode=0xC6, .mnemonic="DEC", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.dec},
    .{.opcode=0xD6, .mnemonic="DEC", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.dec},
    .{.opcode=0xCE, .mnemonic="DEC", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.dec},
    .{.opcode=0xDE, .mnemonic="DEC", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.dec},
   
    .{.opcode=0xCA, .mnemonic="DEX", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.dex},
    .{.opcode=0x88, .mnemonic="DEY", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.dey},
  
    .{.opcode=0x49, .mnemonic="EOR", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.eor},
    .{.opcode=0x45, .mnemonic="EOR", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.eor},
    .{.opcode=0x55, .mnemonic="EOR", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.eor},
    .{.opcode=0x4D, .mnemonic="EOR", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.eor},
    .{.opcode=0x5D, .mnemonic="EOR", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.eor},
    .{.opcode=0x59, .mnemonic="EOR", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.eor},
    .{.opcode=0x41, .mnemonic="EOR", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.eor},
    .{.opcode=0x51, .mnemonic="EOR", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.eor},
    
    .{.opcode=0xE6, .mnemonic="INC", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.inc},
    .{.opcode=0xF6, .mnemonic="INC", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.inc},
    .{.opcode=0xEE, .mnemonic="INC", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.inc},
    .{.opcode=0xFE, .mnemonic="INC", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.inc},
    
    .{.opcode=0xE8, .mnemonic="INX", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.inx},
    .{.opcode=0xC8, .mnemonic="INY", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.iny},
   
    .{.opcode=0x4C, .mnemonic="JMP", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 3, .handler_fn = instructions.jmp},
    .{.opcode=0x6C, .mnemonic="JMP", .addressing_mode=.INDIRECT,   .bytes = 3, .cycles = 5, .handler_fn = instructions.jmp},
    .{.opcode=0x20, .mnemonic="JSR", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.jsr},
   
    .{.opcode=0xA9, .mnemonic="LDA", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.lda},
    .{.opcode=0xA5, .mnemonic="LDA", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.lda},
    .{.opcode=0xB5, .mnemonic="LDA", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.lda},
    .{.opcode=0xAD, .mnemonic="LDA", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.lda},
    .{.opcode=0xBD, .mnemonic="LDA", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.lda},
    .{.opcode=0xB9, .mnemonic="LDA", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.lda},
    .{.opcode=0xA1, .mnemonic="LDA", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.lda},
    .{.opcode=0xB1, .mnemonic="LDA", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.lda},
   
    .{.opcode=0xA2, .mnemonic="LDX", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.ldx},
    .{.opcode=0xA6, .mnemonic="LDX", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.ldx},
    .{.opcode=0xB6, .mnemonic="LDX", .addressing_mode=.ZEROPAGE_Y, .bytes = 2, .cycles = 4, .handler_fn = instructions.ldx},
    .{.opcode=0xAE, .mnemonic="LDX", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.ldx},
    .{.opcode=0xBE, .mnemonic="LDX", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.ldx},
   
    .{.opcode=0xA0, .mnemonic="LDY", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.ldy},
    .{.opcode=0xA4, .mnemonic="LDY", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.ldy},
    .{.opcode=0xB4, .mnemonic="LDY", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.ldy},
    .{.opcode=0xAC, .mnemonic="LDY", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.ldy},
    .{.opcode=0xBC, .mnemonic="LDY", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.ldy},
   
    .{.opcode=0x4A, .mnemonic="LSR", .addressing_mode=.ACCUMULATOR,.bytes = 1, .cycles = 2, .handler_fn = instructions.lsr},
    .{.opcode=0x46, .mnemonic="LSR", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.lsr},
    .{.opcode=0x56, .mnemonic="LSR", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.lsr},
    .{.opcode=0x4E, .mnemonic="LSR", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.lsr},
    .{.opcode=0x5E, .mnemonic="LSR", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.lsr},
   
    .{.opcode=0xEA, .mnemonic="NOP", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.nop},
    
    .{.opcode=0x09, .mnemonic="ORA", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.ora},
    .{.opcode=0x05, .mnemonic="ORA", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.ora},
    .{.opcode=0x15, .mnemonic="ORA", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.ora},
    .{.opcode=0x0D, .mnemonic="ORA", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.ora},
    .{.opcode=0x1D, .mnemonic="ORA", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.ora},
    .{.opcode=0x19, .mnemonic="ORA", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.ora},
    .{.opcode=0x01, .mnemonic="ORA", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.ora},
    .{.opcode=0x11, .mnemonic="ORA", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.ora},
    
    .{.opcode=0x48, .mnemonic="PHA", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 3, .handler_fn = instructions.pha},
    .{.opcode=0x08, .mnemonic="PHP", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 3, .handler_fn = instructions.php},
    .{.opcode=0x68, .mnemonic="PLA", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 4, .handler_fn = instructions.pla},
    .{.opcode=0x28, .mnemonic="PLP", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 4, .handler_fn = instructions.plp},
    
    .{.opcode=0x6A, .mnemonic="ROR", .addressing_mode=.ACCUMULATOR,.bytes = 1, .cycles = 2, .handler_fn = instructions.ror},
    .{.opcode=0x66, .mnemonic="ROR", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.ror},
    .{.opcode=0x76, .mnemonic="ROR", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.ror},
    .{.opcode=0x6E, .mnemonic="ROR", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.ror},
    .{.opcode=0x7E, .mnemonic="ROR", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.ror},
    
    .{.opcode=0x2A, .mnemonic="ROL", .addressing_mode=.ACCUMULATOR,.bytes = 1, .cycles = 2, .handler_fn = instructions.rol},
    .{.opcode=0x26, .mnemonic="ROL", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 5, .handler_fn = instructions.rol},
    .{.opcode=0x36, .mnemonic="ROL", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.rol},
    .{.opcode=0x2E, .mnemonic="ROL", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 6, .handler_fn = instructions.rol},
    .{.opcode=0x3E, .mnemonic="ROL", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 7, .handler_fn = instructions.rol},
    
    .{.opcode=0x40, .mnemonic="RTI", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 6, .handler_fn = instructions.rti},
    .{.opcode=0x60, .mnemonic="RTS", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 6, .handler_fn = instructions.rts},
    
    .{.opcode=0xE9, .mnemonic="SBC", .addressing_mode=.IMMEDIATE,  .bytes = 2, .cycles = 2, .handler_fn = instructions.sbc},
    .{.opcode=0xE5, .mnemonic="SBC", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.sbc},
    .{.opcode=0xF5, .mnemonic="SBC", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.sbc},
    .{.opcode=0xED, .mnemonic="SBC", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.sbc},
    .{.opcode=0xFD, .mnemonic="SBC", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 4, .handler_fn = instructions.sbc},
    .{.opcode=0xF9, .mnemonic="SBC", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 4, .handler_fn = instructions.sbc},
    .{.opcode=0xE1, .mnemonic="SBC", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.sbc},
    .{.opcode=0xF1, .mnemonic="SBC", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 5, .handler_fn = instructions.sbc},
    
    .{.opcode=0x38, .mnemonic="SEC", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.sec},
    .{.opcode=0xF8, .mnemonic="SED", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.sed},
    .{.opcode=0x78, .mnemonic="SEI", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.sei},
    
    .{.opcode=0x85, .mnemonic="STA", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.sta},
    .{.opcode=0x95, .mnemonic="STA", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.sta},
    .{.opcode=0x8D, .mnemonic="STA", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.sta},
    .{.opcode=0x9D, .mnemonic="STA", .addressing_mode=.ABSOLUTE_X, .bytes = 3, .cycles = 5, .handler_fn = instructions.sta},
    .{.opcode=0x99, .mnemonic="STA", .addressing_mode=.ABSOLUTE_Y, .bytes = 3, .cycles = 5, .handler_fn = instructions.sta},
    .{.opcode=0x81, .mnemonic="STA", .addressing_mode=.INDIRECT_X, .bytes = 2, .cycles = 6, .handler_fn = instructions.sta},
    .{.opcode=0x91, .mnemonic="STA", .addressing_mode=.INDIRECT_Y, .bytes = 2, .cycles = 6, .handler_fn = instructions.sta},
    .{.opcode=0x86, .mnemonic="STX", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.stx},
    .{.opcode=0x96, .mnemonic="STX", .addressing_mode=.ZEROPAGE_Y, .bytes = 2, .cycles = 4, .handler_fn = instructions.stx},
    .{.opcode=0x8E, .mnemonic="STX", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.stx},
    
    .{.opcode=0x84, .mnemonic="STY", .addressing_mode=.ZEROPAGE,   .bytes = 2, .cycles = 3, .handler_fn = instructions.sty},
    .{.opcode=0x94, .mnemonic="STY", .addressing_mode=.ZEROPAGE_X, .bytes = 2, .cycles = 4, .handler_fn = instructions.sty},
    .{.opcode=0x8C, .mnemonic="STY", .addressing_mode=.ABSOLUTE,   .bytes = 3, .cycles = 4, .handler_fn = instructions.sty},
    
    .{.opcode=0xAA, .mnemonic="TAX", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.tax},
    .{.opcode=0xA8, .mnemonic="TAY", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.tay},
    .{.opcode=0xBA, .mnemonic="TSX", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.tsx},
    .{.opcode=0x8A, .mnemonic="TXA", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.txa},
    .{.opcode=0x9A, .mnemonic="TXS", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.txs},
    .{.opcode=0x98, .mnemonic="TYA", .addressing_mode=.IMPLIED,    .bytes = 1, .cycles = 2, .handler_fn = instructions.tya},

};

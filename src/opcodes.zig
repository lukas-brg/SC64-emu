const std = @import("std");

const AdressingMode = enum {
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

const OpcodeStruct = struct {
    opcode: u8,
    op_name: []const u8,
    addressing_mode: AdressingMode,
    bytes: u3,
    cycles: u3,

    pub fn print(self: OpcodeStruct) void {
        std.debug.print("\nOpcode: {}, Name: {s}, Addressing Mode: {}, Bytes: {}, Cycles: {})\n",
            .{self.opcode, self.op_name, self.addressing_mode, self.bytes, self.cycles});
        }
};


pub const OPCODES = [_]OpcodeStruct{
    .{.opcode=0x69, .op_name="ADC", .addressing_mode=AdressingMode.IMMEDIATE,  .bytes = 2, .cycles = 2},
    .{.opcode=0x65, .op_name="ADC", .addressing_mode=AdressingMode.ZEROPAGE,   .bytes = 2, .cycles = 3},
    .{.opcode=0x75, .op_name="ADC", .addressing_mode=AdressingMode.ZEROPAGE_X, .bytes = 2, .cycles = 4},
    .{.opcode=0x6D, .op_name="ADC", .addressing_mode=AdressingMode.ABSOLUTE,   .bytes = 3, .cycles = 4},
    .{.opcode=0x7D, .op_name="ADC", .addressing_mode=AdressingMode.ABSOLUTE_X, .bytes = 3, .cycles = 4},
    .{.opcode=0x79, .op_name="ADC", .addressing_mode=AdressingMode.ABSOLUTE_Y, .bytes = 3, .cycles = 4},
    .{.opcode=0x61, .op_name="ADC", .addressing_mode=AdressingMode.INDIRECT_X, .bytes = 2, .cycles = 6},
    .{.opcode=0x71, .op_name="ADC", .addressing_mode=AdressingMode.INDIRECT_Y, .bytes = 2, .cycles = 5},
    
    .{.opcode=0x29, .op_name="AND", .addressing_mode=AdressingMode.IMMEDIATE,  .bytes = 2, .cycles = 2},
    .{.opcode=0x25, .op_name="AND", .addressing_mode=AdressingMode.ZEROPAGE,   .bytes = 2, .cycles = 3},
    .{.opcode=0x35, .op_name="AND", .addressing_mode=AdressingMode.ZEROPAGE_X, .bytes = 2, .cycles = 4},
    .{.opcode=0x2D, .op_name="AND", .addressing_mode=AdressingMode.ABSOLUTE,   .bytes = 3, .cycles = 4},
    .{.opcode=0x3D, .op_name="AND", .addressing_mode=AdressingMode.ABSOLUTE_X, .bytes = 3, .cycles = 4},
    .{.opcode=0x39, .op_name="AND", .addressing_mode=AdressingMode.ABSOLUTE_Y, .bytes = 3, .cycles = 4},
    .{.opcode=0x21, .op_name="AND", .addressing_mode=AdressingMode.INDIRECT_X, .bytes = 2, .cycles = 6},
    .{.opcode=0x31, .op_name="AND", .addressing_mode=AdressingMode.INDIRECT_Y, .bytes = 2, .cycles = 5},

    .{.opcode=0x0A, .op_name="ASL", .addressing_mode=AdressingMode.ZEROPAGE,   .bytes = 1, .cycles = 2},
    .{.opcode=0x06, .op_name="ASL", .addressing_mode=AdressingMode.ZEROPAGE_X, .bytes = 2, .cycles = 5},
    .{.opcode=0x16, .op_name="ASL", .addressing_mode=AdressingMode.ABSOLUTE,   .bytes = 2, .cycles = 6},
    .{.opcode=0x0E, .op_name="ASL", .addressing_mode=AdressingMode.ABSOLUTE_X, .bytes = 3, .cycles = 6},
    .{.opcode=0x1E, .op_name="ASL", .addressing_mode=AdressingMode.ABSOLUTE_Y, .bytes = 3, .cycles = 7},
    
    .{.opcode=0x90, .op_name="BCC", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0xB0, .op_name="BCS", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0xF0, .op_name="BEQ", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0x30, .op_name="BMI", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0xD0, .op_name="BNE", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0x10, .op_name="BFL", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0x50, .op_name="BVC", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    .{.opcode=0x70, .op_name="BVS", .addressing_mode=AdressingMode.RELATIVE, .bytes = 2, .cycles = 2},
    
    .{.opcode=0x00, .op_name="BRK", .addressing_mode=AdressingMode.IMPLIED,  .bytes = 1, .cycles = 7},

    .{.opcode=0x18, .op_name="CLC", .addressing_mode=AdressingMode.IMPLIED, .bytes = 1, .cycles = 2},
    .{.opcode=0xD8, .op_name="CLD", .addressing_mode=AdressingMode.IMPLIED, .bytes = 1, .cycles = 2},
    .{.opcode=0x58, .op_name="CLV", .addressing_mode=AdressingMode.IMPLIED, .bytes = 1, .cycles = 2},
    
    .{.opcode=0xC9, .op_name="CMP", .addressing_mode=AdressingMode.IMMEDIATE,  .bytes = 2, .cycles = 2},
    .{.opcode=0xC5, .op_name="CMP", .addressing_mode=AdressingMode.ZEROPAGE,   .bytes = 2, .cycles = 3},
    .{.opcode=0xD5, .op_name="CMP", .addressing_mode=AdressingMode.ZEROPAGE_X, .bytes = 2, .cycles = 4},
    .{.opcode=0xCD, .op_name="CMP", .addressing_mode=AdressingMode.ABSOLUTE,   .bytes = 3, .cycles = 4},
    .{.opcode=0xDD, .op_name="CMP", .addressing_mode=AdressingMode.ABSOLUTE_X, .bytes = 3, .cycles = 4},
    .{.opcode=0xD9, .op_name="CMP", .addressing_mode=AdressingMode.ABSOLUTE_Y, .bytes = 3, .cycles = 4},
    .{.opcode=0xC1, .op_name="CMP", .addressing_mode=AdressingMode.INDIRECT_X, .bytes = 2, .cycles = 6},
    .{.opcode=0xD1, .op_name="CMP", .addressing_mode=AdressingMode.INDIRECT_Y, .bytes = 2, .cycles = 5},
    
    .{.opcode=0x1, .op_name="ORA", .addressing_mode=AdressingMode.INDIRECT_Y, .bytes = 2, .cycles = 5},
    .{.opcode=0x5, .op_name="ORA", .addressing_mode=AdressingMode.ZEROPAGE, .bytes = 2, .cycles = 3},
 

};
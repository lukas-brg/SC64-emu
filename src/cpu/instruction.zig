const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpcodeInfo = @import("opcodes.zig").OpcodeInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const bitutils = @import("bitutils.zig");



pub const Instruction = struct {
    operand: ?u8 = null,
    operand_addr: ?u16 = null,
    page_crossed: bool,
    cycles: u4, // There can be additional cycles if a page boundary was crossed, so this parameter is used again
    instruction_addr: u16,
    mnemonic: []const u8,
    addressing_mode: AddressingMode,
    bytes: u8,

    pub fn print(self: Instruction) void {
        std.debug.print("(Operand: {?x:0>4}, Address: {?x:0>2}, Page Crossed: {}, Cycles: {})\n",
        .{self.operand, self.operand_addr, self.page_crossed, self.cycles});
    }
};

inline fn page_boundary_crossed(pc: u16, addr: u16) bool {
    // A page boundary is crossed when the high byte differs
    return (pc & 0xFF00) != (addr & 0xFF00);
}

pub fn get_instruction(cpu: *CPU, opcode: OpcodeInfo) Instruction {
    var address: ?u16 = null;
    var operand: ?u8 = null;
    var page_crossed = false;
    const pc = cpu.PC;

    switch (opcode.addressing_mode) {
        .IMMEDIATE => {
            const addr = pc + 1;
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ABSOLUTE => {
            const addr = cpu.bus.read_16(pc+1);
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ABSOLUTE_X => {
            const addr = cpu.bus.read_16(pc+1) +% cpu.X;
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ABSOLUTE_Y => {
            const addr = cpu.bus.read_16(pc+1) +%  cpu.Y;
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;

        },
        .ZEROPAGE => {
            const addr = @as(u16, cpu.bus.read(pc+1));
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ZEROPAGE_X => {
            const addr = @as(u16, cpu.bus.read(pc+1) +% cpu.X);
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ZEROPAGE_Y => {
            const addr = @as(u16, cpu.bus.read(pc+1) +% cpu.Y);
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .RELATIVE => {
            const offset: u8 = cpu.bus.read(pc + 1);
            if ((offset & 0x80) != 0) {
                address = pc + opcode.bytes - (0x100 - @as(u16, offset));
            } else {
                address = pc + opcode.bytes + offset;
            }
            operand = cpu.bus.read(address.?);
            page_crossed = page_boundary_crossed(pc, address.?);
        },
        .INDIRECT => {
            const lookup_addr = cpu.bus.read_16(pc+1);
            const addr = cpu.bus.read_16(lookup_addr);
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .INDIRECT_X => {
            const lookup_addr: u16 = @as(u16, cpu.bus.read(pc+1) +% cpu.X);
            const addr = cpu.bus.read_16(lookup_addr);
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .INDIRECT_Y => {
            const lookup_addr: u16 = @as(u16, cpu.bus.read(pc+1));
            const addr = cpu.bus.read_16(lookup_addr)  +% cpu.Y;
            operand = cpu.bus.read(addr);
            page_crossed = page_boundary_crossed(pc, addr);
            address = addr;
        },
        .ACCUMULATOR => {
            operand = cpu.A;
        },
        else => {},
    }

    return .{
        .operand = operand, 
        .operand_addr = address, 
        .page_crossed = page_crossed, 
        .cycles = opcode.cycles + @intFromBool(page_crossed), 
        .instruction_addr  = pc,
        .mnemonic = opcode.mnemonic,
        .addressing_mode = opcode.addressing_mode,
        .bytes = opcode.bytes,
    };
}

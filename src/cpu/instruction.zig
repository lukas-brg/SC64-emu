const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpcodeInfo = @import("opcodes.zig").OpcodeInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const bitutils = @import("bitutils.zig");

pub fn get_operand_address(cpu: *CPU, opcode: OpcodeInfo) u16 {
    const address: u16 = switch (opcode.addressing_mode) {
        .IMMEDIATE => cpu.PC + 1,
        .ABSOLUTE => cpu.bus.read_16(cpu.PC + 1),
        .ABSOLUTE_X => cpu.bus.read_16(cpu.PC + 1) +% cpu.X,
        .ABSOLUTE_Y => cpu.bus.read_16(cpu.PC + 1) +% cpu.Y,
        .ZEROPAGE => @as(u16, cpu.bus.read(cpu.PC + 1)),
        .ZEROPAGE_X => @as(u16, cpu.bus.read(cpu.PC + 1) +% cpu.X),
        .ZEROPAGE_Y => @as(u16, cpu.bus.read(cpu.PC + 1) +% cpu.Y),
        .RELATIVE => blk: {
            const offset: u8 = cpu.bus.read(cpu.PC + 1);
            if ((offset & 0x80) != 0) {
                //const signed_offset =  -1 * (0x100 - offset);
                break :blk cpu.PC + opcode.bytes - (0x100 - @as(u16, offset));
            } else {
                break :blk cpu.PC + opcode.bytes + offset;
            }
        },
        .INDIRECT => blk: {
            const lookup_addr = cpu.bus.read_16(cpu.PC + 1);
            const addr = cpu.bus.read_16(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_X => blk: {
            const lookup_addr: u16 = @as(u16, cpu.bus.read(cpu.PC + 1) +% cpu.X);
            const addr = cpu.bus.read_16(lookup_addr);
            break :blk addr;
        },
        .INDIRECT_Y => blk: {
            const lookup_addr: u16 = @as(u16, cpu.bus.read(cpu.PC + 1));
            const addr = cpu.bus.read_16(lookup_addr) +% cpu.Y;
            break :blk addr;
        },
        .IMPLIED => undefined,
        .ACCUMULATOR => undefined,
    };

    return address;
}

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
        std.debug.print("(Operand: {?x:0>4}, Address: {?x:0>2}, Page Crossed: {}, Cycles: {})\n", .{ self.operand, self.operand_addr, self.page_crossed, self.cycles });
    }
};

fn page_boundary_crossed(cpu: *CPU, addr: u16) bool {
    // A page boundary is crossed when the high byte changes
    return (cpu.PC & 0xFF00) != (addr & 0xFF00);
}

pub fn get_instruction(cpu: *CPU, opcode: OpcodeInfo) Instruction {
    const operand_info: Instruction = switch (opcode.addressing_mode) {
        .ACCUMULATOR => .{
            .operand = cpu.A,
            .operand_addr = null,
            .page_crossed = false,
            .cycles = opcode.cycles,
            .instruction_addr = cpu.PC,
            .mnemonic = opcode.mnemonic,
            .addressing_mode = opcode.addressing_mode,
            .bytes = opcode.bytes,
        },

        .IMPLIED => .{
            .operand = null,
            .operand_addr = null,
            .page_crossed = false,
            .cycles = opcode.cycles,
            .instruction_addr = cpu.PC,
            .mnemonic = opcode.mnemonic,
            .addressing_mode = opcode.addressing_mode,
            .bytes = opcode.bytes,
        },

        else => blk: {
            const address = get_operand_address(cpu, opcode);
            const operand = cpu.bus.read(address);
            const page_crossed = page_boundary_crossed(cpu, address);
            const cycles = opcode.cycles + @intFromBool(page_crossed); // If a page cross happens instructions take one cycle more to execute

            break :blk .{
                .operand = operand,
                .operand_addr = address,
                .page_crossed = page_crossed,
                .cycles = cycles,
                .instruction_addr = cpu.PC,
                .mnemonic = opcode.mnemonic,
                .addressing_mode = opcode.addressing_mode,
                .bytes = opcode.bytes,
            };
        },
    };

    // if (cpu.print_debug_info) {
    //     operand_info.print();
    // }

    return operand_info;
}

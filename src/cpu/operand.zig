const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const OpInfo = @import("opcodes.zig").OpInfo;
const AddressingMode = @import("opcodes.zig").AddressingMode;
const DEBUG_CPU = @import("cpu.zig").DEBUG_CPU;

const combine_bytes = @import("bitutils.zig").combine_bytes;


pub fn get_operand_address(cpu: *CPU, instruction: OpInfo) u16 {

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
        .IMPLIED => undefined,
        .ACCUMULATOR => undefined,
   
    };
    return address;
}

const OperandInfo = struct {
    operand: u8,
    address: u16,
    page_crossed: bool,
    cycles: u3, // There can be additional cycles if a page boundary was crossed, so this parameter is used again

    pub fn print(self: OperandInfo) void {
        std.debug.print("(Operand: {x:0>4}, Address: {x:0>2}, Page Crossed: {}, Cycles: {})\n",
        .{self.operand, self.address, self.page_crossed, self.cycles});
    }
};

fn page_boundary_crossed(cpu: *CPU, addr: u16) bool {
    _ = cpu;
    _ = addr;
    return false;
}

pub fn get_operand(cpu: *CPU, instruction: OpInfo) OperandInfo {
    const op_info: OperandInfo = switch (instruction.addressing_mode) {
        .ACCUMULATOR => .{
            .operand = cpu.A,
            .address = undefined,
            .page_crossed = false,
            .cycles = instruction.cycles,
        },

        .IMPLIED => .{
            .operand = undefined,
            .address = undefined,
            .page_crossed = false,
            .cycles = instruction.cycles,
        },

        else => blk: {
            const address = get_operand_address(cpu, instruction);
            const operand = cpu.bus.read(address);
            const page_crossed = page_boundary_crossed(cpu, address);
            const cycles = instruction.cycles + @intFromBool(page_crossed); // If a page cross happens instructions take one cycle more to execute

            break :blk .{.operand=operand, .address=address, .page_crossed=page_crossed, .cycles=cycles};
        }
    };

   

    if (DEBUG_CPU) {
        std.debug.print("Instruction fetched ", .{});
        instruction.print();
        op_info.print();
    } 
   
    return op_info;
}

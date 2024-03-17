const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const StatusFlag = @import("cpu.zig").StatusFlag;
const InstructionStruct = @import("opcodes.zig").InstructionStruct;


pub fn adc(cpu: *CPU, instruction: InstructionStruct) void {
    _ = cpu;
    _ = instruction;
    std.debug.print("adc called\n", .{});
}


pub fn dummy(cpu: *CPU, instruction: InstructionStruct) void {
    _ = cpu;
    std.debug.print("dummy called\n", .{});
    instruction.print();
}
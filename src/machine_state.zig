const instr = @import("cpu/instruction.zig");

pub var current_cycle: usize = 0;
pub var current_instruction: ?instr.Instruction = null;
pub var current_pc: u16 = 0;

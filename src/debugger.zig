const Emulator = @import("emulator.zig").Emulator;
const CPU = @import("cpu/cpu.zig").CPU;

const BreakPoint = union(enum) {
    addr: u16, // Break at PC=addr;
    instruction: usize, // Break at instruction no.
    cycle: usize,  // Break at cycle no. 
    disasm: []u8, // Break when disasm regex matches the dissassembly of an instruction
};

pub fn runTerminalDebugger() !void {
}

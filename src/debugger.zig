const Emulator = @import("emulator.zig").Emulator;
const CPU = @import("cpu/cpu.zig").CPU;


const DebuggerConfig = struct {
    start_at_instruction: usize,
};


pub fn run_terminal_debugger(config: DebuggerConfig) !void {
    _ = config;
    

}
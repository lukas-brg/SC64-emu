pub const EmulatorConfig = struct {
    headless: bool = false,
    scaling_factor: f32 = 3,
    enable_bank_switching: bool = true,
    speedup_startup: bool = true,
};

pub const DebugTraceConfig = struct {
    enable_trace: bool = false,
    print_mem: bool = true,
    print_mem_window_size: usize = 0x20,
    print_stack: bool = false,
    print_stack_limit: usize = 10,
    print_cpu_state: bool = true,
    start_at_cycle: usize = 0,
    start_at_instr: usize = 0,
    capture_addr: ?u16 = 0,
    end_at_cycle: ?usize = null,
    verbose: bool = false,
};
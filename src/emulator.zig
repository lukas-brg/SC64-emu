const std = @import("std");
const builtin = @import("builtin");
const graphics = @import("graphics.zig");
const io = @import("io.zig");

const raylib = graphics.raylib;

const PrecisionClock = @import("clock.zig").PrecisionClock;
const CPU = @import("cpu/cpu.zig").CPU;
const Bus = @import("bus.zig").Bus;
const MemoryMap = @import("bus.zig").MemoryMap;
const bitutils = @import("cpu/bitutils.zig");
const colors = graphics.colors;
const Renderer = graphics.Renderer;
const instruction = @import("cpu/instruction.zig");
const kb = @import("keyboard.zig");

const conf = @import("config.zig");

const print_disassembly_inline = @import("cpu/cpu.zig").print_disassembly_inline;


const log_emu = std.log.scoped(.emu_core);

var sigint_received: bool = false;

export fn catch_sigint(_: i32) void {
    sigint_received = true;
    //@atomicStore(bool, &sigint_received, true, std.builtin.AtomicOrder.release);
   
}


fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize)) catch |err|{
        log_emu.err("Could not read file '{s}'", .{rom_path});
        return err;
    };
    return data;
}



pub const Emulator = struct {
    bus: *Bus,
    cpu: *CPU,
    keyboard: *kb.Keyboard,
    config: conf.EmulatorConfig = .{},
    trace_config: conf.DebugTraceConfig = .{},
    step_count: usize = 0,
    cia1: *io.CiaI,
    vic: ?graphics.VicII = null,
    __tracing_active: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: conf.EmulatorConfig) !Emulator {
        
        const bus = try allocator.create(Bus);
        const cpu = try allocator.create(CPU);
        const keyboard = try allocator.create(kb.Keyboard);
        const cia1 = try allocator.create(io.CiaI);
        keyboard.* = kb.Keyboard.init();
        cia1.* = io.CiaI.init(cpu, keyboard);
        bus.* = Bus.init(cia1);
        bus.enable_bank_switching = config.enable_bank_switching;
        cpu.* = CPU.init(bus);
        const emulator: Emulator = .{
            .bus = bus,
            .cpu = cpu,
            .keyboard = keyboard,
            .config = config,
            .cia1 = cia1
        };

        if (!config.headless) {
            log_emu.info("Starting emulator in windowed mode...", .{});
        } else {
            log_emu.info("Starting emulator in headless mode...", .{});
        } 
        log_emu.debug("Bank switching: {}", .{config.enable_bank_switching});

        cpu.print_debug_info = false; // This flag will be set based on the other parameters later in print_debug_output()

        return emulator;
    }

    pub fn init_graphics(self: *Emulator) !void {
        self.bus.write(MemoryMap.bg_color, colors.BG_COLOR);
        self.bus.write(MemoryMap.text_color, colors.TEXT_COLOR);
        self.bus.write(MemoryMap.frame_color, colors.FRAME_COLOR);
        self.load_character_rom("data/c64_charset.bin");
       // self.clear_color_mem();
        log_emu.info("C64 graphics initialized", .{});
    }

    pub fn init_c64(self: *Emulator) !void {
        self.load_basic_rom() catch std.debug.panic("Couldn't load BASIC rom", .{});
        self.load_kernal_rom() catch std.debug.panic("Couldn't load KERNAL rom", .{});

        self.bus.write(0, 0x2F); // direction register
        self.bus.write(1, 0x37); // processor port

        self.cpu.reset();
        try self.init_graphics();
        self.cpu.SP = 0xFF;
        log_emu.info("C64 init procedure completed", .{});
    }

    fn load_basic_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/basic.bin", allocator);
        @memcpy(self.bus.basic_rom[0..], rom_data);
        allocator.free(rom_data);
        log_emu.info("Loaded BASIC rom", .{});
    }

    fn load_character_rom(self: *Emulator, charset_path: []const u8) void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        
        const rom_data = load_file_data(charset_path, allocator) catch {
            std.debug.panic("Couldn't load charset {s}", .{charset_path});
        };
        defer allocator.free(rom_data);

        @memcpy(self.bus.character_rom[0..], rom_data);
        log_emu.info("Loaded charset '{s}' into character rom", .{charset_path});
    }

    pub fn set_trace_config(self: *Emulator, config: conf.DebugTraceConfig) void {
        self.trace_config = config;
        // Activate tracing automatically if trace_start parameter is set
        const enable = config.enable_trace or (config.start_at_cycle > 0) or (config.start_at_instr > 0);
        self.trace_config.enable_trace = enable;
    }

    fn load_kernal_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/kernal.bin", allocator);
        @memcpy(self.bus.kernal_rom[0..], rom_data);
        allocator.free(rom_data);
        log_emu.info("Loaded KERNAL rom", .{});
    }

    pub fn deinit(self: Emulator, allocator: std.mem.Allocator) void {
        allocator.destroy(self.bus);
        allocator.destroy(self.cia1);
        allocator.destroy(self.cpu);
        allocator.destroy(self.keyboard);
        log_emu.info("All resources deallocated", .{});
    }

    pub fn load_rom(self: *Emulator, rom_path: []const u8, offset: u16) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = load_file_data(rom_path, allocator) catch {
            std.debug.panic("Could not load rom '{s}' file data", .{rom_path});
        };
        self.cpu.bus.write_continuous(rom_data, offset);
        allocator.free(rom_data);
        log_emu.info("Loaded rom data from file '{s}' at offset {X:0>4}", .{ rom_path, offset });
    }


    pub fn step(self: *Emulator) void {
        //self.cia1.dec_timers();
        
        self.cpu.clock_tick();
        
        self.print_trace();
        
        if (self.step_count % 1 == 0) {
            // io.keyboard.update_keyboard_state(self);
            self.keyboard.update();
            
            //std.debug.print("A={b:0>8}  B={b:0>8}\n", .{self.bus.read(0xDC00), self.bus.read(0xDC01)});
        }
        self.step_count += 1;
    }


    fn create_sigint_handler() void {
        switch (comptime builtin.os.tag) {
            .windows => log_emu.warn("SIGINT handler not supported on Windows yet.", .{}),
            else => {
                var act = std.posix.Sigaction{ 
                    .handler = .{ .handler = catch_sigint },
                    .mask = std.posix.empty_sigset,
                    .flags = 0,
                };

                std.posix.sigaction(std.posix.SIG.INT, &act, null) catch {
                    log_emu.warn("Unable to create SIGINT handler on os: {s}", .{ @tagName(builtin.os.tag) });
                };
            },
        }
    }
    

    pub fn run(self: *Emulator, limit_cycles: ?usize, limit_instructions: ?usize) void {
       
        create_sigint_handler();
        self.cpu.reset();
        var clock = PrecisionClock.init(if (self.config.speedup_startup) 100  else 1000);
        var vic_clock = PrecisionClock.init(16666667);
     
        var vic = graphics.VicII.init(self.bus, self.cpu, self.config.scaling_factor);
        
        // if (!self.config.headless) {

            const rendering_thread = std.Thread.spawn(.{}, graphics.VicII.run, .{&vic, &vic_clock}) catch |err| {
                std.debug.panic("Spawing rendering thread failed {any}", .{err});
            };
        
            defer rendering_thread.join();
        // }
        
        var quit = false;
        log_emu.info("Starting execution...", .{});
        
        const starttime_ms = std.time.milliTimestamp();
        var adjusted = false;
        while (!quit) {
            clock.start();
            self.step(); 
            
            if (!adjusted and self.cpu.PC >= MemoryMap.basic_rom_start and self.cpu.PC <= MemoryMap.basic_rom_end) {
                // std.debug.print("asdasdads", .{});
                clock.target_duration_ns = 1015;
                adjusted = true;
            }
            quit = sigint_received or @atomicLoad(bool, &vic.termination_requested, std.builtin.AtomicOrder.acquire);
            
            if (limit_instructions) |max_instr| {
                if (self.cpu.instruction_count >= max_instr) {
                    log_emu.info("Instruction limit reached: {} >= {} - Stopping execution...", .{self.cpu.instruction_count, max_instr});
                    break;  
                } 
            }

            if (limit_cycles) |max_cycles| {
                if (self.cpu.cycle_count >= max_cycles) {
                    log_emu.info("Cycle limit reached: {} >= {} - Stopping execution...", .{self.cpu.cycle_count, max_cycles});
                    break;  
                } 
            }
            clock.end();
        }
        const endtime_ms = std.time.milliTimestamp();
        
        @atomicStore(bool, &vic.termination_requested, true, .release);
        if (sigint_received) {
            log_emu.info("Received signal SIGINT - Stopping execution...", .{});
        }

        const runtime_ms = endtime_ms - starttime_ms;
        self.vic = vic;
        self.log_runtime_stats(runtime_ms);
    }


    /// Like run but automatically detects infinite loop or success and stops execution
    pub fn run_ftest(self: *Emulator, limit_cycles: ?usize, addr_success: u16) bool {
        create_sigint_handler();
        self.cpu.reset();
        var quit = false;
        
        var pc_prev: u16 = undefined;
        var cpu_state_prev: CPU = self.cpu.*;
        log_emu.info("Starting execution of functional test...", .{});
        var passed = false;
        const starttime_ms = std.time.milliTimestamp();
        while (!quit) {
            pc_prev = self.cpu.PC;
            self.cpu.step();
            self.print_trace();
            self.step_count += 1;
            quit = sigint_received;
            if (pc_prev == self.cpu.PC) {
                if (self.cpu.PC == addr_success) {
                    std.debug.print("\x1b[32mFunctional test success!\x1b[0m [PC={X:0>4}, Cycle={}, #Instruction: {}]\n", .{
                        self.cpu.PC,
                        self.cpu.cycle_count,
                        self.cpu.instruction_count,
                    });
                    passed = true;
                    break;
                } else {
                    std.debug.print("\x1b[31mFunctional test failed!\x1b[0m [PC={X:0>4}, Cycle={}, #Instruction: {}]\n", .{
                        self.cpu.PC,
                        self.cpu.cycle_count,
                        self.cpu.instruction_count,
                    });
                    cpu_state_prev.print_state_compact();
                    self.cpu.print_state_compact();
                    break;
                }
            }

            cpu_state_prev = self.cpu.*; // Todo: make tracing functions generate strings, so a list of recent traces can be stored
                                          // instead of copying the whole cpu

            if (limit_cycles) |max_cycles| {
                if (self.cpu.cycle_count >= max_cycles) {
                    log_emu.info("Cycle limit reached: {} >= {} - Stopping execution...", .{self.cpu.cycle_count, max_cycles});
                    break;  
                } 
            }
        }
        const endtime_ms = std.time.milliTimestamp();

        if (sigint_received) {
            log_emu.info("Received signal SIGINT - Stopping execution...", .{});
        }

        const runtime_ms = endtime_ms - starttime_ms;
        self.log_runtime_stats(runtime_ms);
        return passed;
    }


    fn print_trace(self: *Emulator) void {
       
        const cfg = self.trace_config;
        
        const do_print_trace: bool = blk: {
            if (self.__tracing_active) break :blk true;
            const cycle = self.cpu.cycle_count;
            const instr = self.cpu.instruction_count;
            const addr = self.cpu.current_instruction.?.instruction_addr;
            
            
            if (cfg.capture_addr) |caddr| {
                if (addr == caddr) {
                    break :blk true;
                } 
            }
            if (!cfg.enable_trace) {
                break :blk false;
            }

            if (cfg.end_at_cycle) |endc| {
                if (cycle > endc) {
                    break: blk false;
                }
            }


            if (cfg.start_at_cycle > cfg.start_at_instr) {
                break :blk cycle >= cfg.start_at_cycle;
            } else {
                break :blk instr >= cfg.start_at_instr;
            }

        };
        
        if (do_print_trace) {
            if (cfg.verbose) {
                const mem_window_size: i32 = @intCast(self.trace_config.print_mem_window_size);
                const start: u16 = @intCast(@max(0, @as(i32, @intCast(self.cpu.PC)) - @divFloor(mem_window_size, 2)));
                const end = @min(self.bus.mem_size, @as(u17, start) + mem_window_size);

                if (self.trace_config.print_cpu_state) {
                    self.cpu.print_state();
                }

                if (self.trace_config.print_stack) {
                    self.cpu.print_stack(self.trace_config.print_stack_limit);
                }

                if (self.trace_config.print_mem) {
                    self.cpu.bus.print_mem(start, @intCast(end));
                    self.cpu.bus.print_mem(0xc0, @intCast(0xc9));
                }
            } else {
                self.cpu.print_state_compact();
            }
        }
    }


    fn log_runtime_stats(self: *Emulator, runtime_ms: i64) void {
        const runtime_s: f64 = @as(f64, @floatFromInt(runtime_ms)) / 1000.0;
        const freq_c = @as(f64, @floatFromInt(self.cpu.cycle_count)) / @as(f64, @floatFromInt((runtime_ms * 1000)));
        const freq_i = @as(f64, @floatFromInt(self.cpu.instruction_count)) / @as(f64, @floatFromInt((runtime_ms * 1000)));

        
        // Casting to unsigned values because otherwise the formatter will display '+' signs
        var fmt_runtime_ms: u64 = @intCast(runtime_ms);
        
        const fmt_runtime_h: u16 = @intCast(@divTrunc(fmt_runtime_ms, 3600000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 3600000);
        const fmt_runtime_m: u6 = @intCast(@divTrunc(fmt_runtime_ms, 60000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 60000);
        const fmt_runtime_s: u6 = @intCast(@divTrunc(fmt_runtime_ms, 1000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 1000);

        const n_frames = blk: {
            if (self.vic) |*r| {
                break :blk r.n_frames_rendered;
            } else {
                break :blk 0;
            }
        };
        const framerate = @as(f64, @floatFromInt(n_frames)) / runtime_s;

        log_emu.info(
            \\Emulator execution stopped:
            \\       > Runtime: (h:m:s:ms)     {}:{d:0>2}:{d:0>2}:{d:0>3} / {d:0.3}s
            \\       > Cycles completed:       {} 
            \\       > Instructions executed:  {}
            \\       > Avg. clock speed:       {d:0.3} MHz
            \\       > Avg. instruction rate:  {d:0.3} MIPS
            \\       > Frames rendered:        {}
            \\       > Avg. framerate:         {d:0.2} FPS
            ,
            .{ 
                fmt_runtime_h,
                fmt_runtime_m,
                fmt_runtime_s,
                fmt_runtime_ms,
                runtime_s, 
                self.cpu.cycle_count, 
                self.cpu.instruction_count, 
                freq_c, 
                freq_i, 
                n_frames,
                framerate,
        });
    }
};

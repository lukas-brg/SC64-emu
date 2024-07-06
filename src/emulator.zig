const std = @import("std");
const builtin = @import("builtin");

const raylib = @import("raylib.zig");

const CPU = @import("cpu/cpu.zig").CPU;
const Bus = @import("bus.zig").Bus;
const MemoryMap = @import("bus.zig").MemoryMap;
const bitutils = @import("cpu/bitutils.zig");
const colors = @import("colors.zig");
const Renderer = @import("renderer.zig").Renderer;
const instruction = @import("cpu/instruction.zig");
const print_disassembly_inline = @import("cpu/cpu.zig").print_disassembly_inline;

const SCREEN_WIDTH = @import("renderer.zig").SCREEN_WIDTH;
const SCREEN_HEIGHT = @import("renderer.zig").SCREEN_HEIGHT;
const BORDER_SIZE_X = @import("renderer.zig").BORDER_SIZE_X;
const BORDER_SIZE_Y = @import("renderer.zig").BORDER_SIZE_Y;

const log_emu = std.log.scoped(.emu_core);

const FTEST_SUCCESS_ADDR = 0x3469;

var sigint_received: bool = false;

export fn catch_sigint(_: i32) void {
    sigint_received = true;
    @atomicStore(bool, &sigint_received, true, std.builtin.AtomicOrder.release);
}


fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return data;
}

pub const EmulatorConfig = struct {
    headless: bool = false,
    scaling_factor: f32 = 4,
    enable_bank_switching: bool = true,
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

pub const Emulator = struct {
    bus: *Bus,
    cpu: *CPU,
    config: EmulatorConfig = .{},
    trace_config: DebugTraceConfig = .{},
    instruction_count: usize = 0,
    renderer: ?Renderer = null,
    __tracing_active: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: EmulatorConfig) !Emulator {
        
        const bus = try allocator.create(Bus);
        bus.* = Bus.init();
        bus.enable_bank_switching = config.enable_bank_switching;
        const cpu = try allocator.create(CPU);
        
        cpu.* = CPU.init(bus);
        const emulator: Emulator = .{
            .bus = bus,
            .cpu = cpu,
            .config = config,
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
        self.clear_color_mem();
        log_emu.info("C64 graphics initialized", .{});
    }

    pub fn init_c64(self: *Emulator) !void {
        self.load_basic_rom() catch std.debug.panic("Couldn't load BASIC rom", .{});
        self.load_kernal_rom() catch std.debug.panic("Couldn't load BASIC rom", .{});

        self.bus.write(0, 0x2F); // direction register
        self.bus.write(1, 0x37); // processor port

        self.bus.write_16(0x281, 0x0800); // Points to BASIC start at $0801
        self.bus.write_16(0x283, 0xA000); // Points to BASIC start at $0801
        //self.bus.write_16(0x00A2, 0xA000); // Points to end of BASIC at $A000

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

        @memcpy(self.bus.character_rom[0..], rom_data);
        allocator.free(rom_data);
        log_emu.info("Loaded charset '{s}' into character rom", .{charset_path});
    }

    pub fn set_trace_config(self: *Emulator, config: DebugTraceConfig) void {
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
        allocator.destroy(self.cpu);
        log_emu.info("All resources deallocated\n", .{});
    }

    pub fn load_rom(self: *Emulator, rom_path: []const u8, offset: u16) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data(rom_path, allocator);
        self.cpu.bus.write_continous(rom_data, offset);
        allocator.free(rom_data);
        log_emu.info("Loaded rom data from file '{s}' at offset {X:0>4}", .{ rom_path, offset });
    }

    pub fn clear_color_mem(self: *Emulator) void {
        @memset(
            self.bus.ram[MemoryMap.color_mem_start..MemoryMap.character_rom_end],
            self.bus.ram[MemoryMap.text_color],
        );
    }

    pub fn clear_screen_mem(self: *Emulator) void {
        @memset(
            self.bus.ram[MemoryMap.screen_mem_start..MemoryMap.screen_mem_end],
            0x20,
        );
    }

    pub fn clear_screen_text_area(self: *Emulator, frame_buffer: []u8) void {
        const color_code: u4 = @truncate(self.bus.read(MemoryMap.bg_color));
        const bg_color = colors.C64_COLOR_PALETTE[color_code];
        for (0..SCREEN_HEIGHT * SCREEN_WIDTH) |i| {
            frame_buffer[i * 3] = bg_color.r;
            frame_buffer[i * 3 + 1] = bg_color.g;
            frame_buffer[i * 3 + 2] = bg_color.b;
        }
    }


    pub fn step(self: *Emulator, frame_buffer: []u8) bool {
        var quit = false;
        self.cpu.step();
        self.print_trace();

        if (self.instruction_count % 70000 == 0) {
            if(self.renderer) |*r| {
                self.clear_screen_text_area(frame_buffer);
                self.update_frame(frame_buffer);
                const border_color = blk: {
                    const color_code: u4 = @truncate(self.bus.read(MemoryMap.frame_color));
                    break :blk colors.C64_COLOR_PALETTE[color_code];
                };
                r.render_frame(frame_buffer, border_color);

                if (r.window_should_close()) {
                    log_emu.info("Window close event detected - Stopping execution...", .{});
                    quit = true;
                } 
            }
        }

        self.instruction_count += 1;
        return quit;
    }

    fn create_sigint_handler() void {
        switch (builtin.os.tag) {
            .windows => log_emu.warn("Windows sigint handler is not supported yet.", .{}),
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
    

    pub fn run(self: *Emulator, limit_cycles: ?usize) !void {
       
        create_sigint_handler();
        
        self.cpu.reset();
        
        var frame_buffer: [3 * SCREEN_HEIGHT * SCREEN_WIDTH]u8 = undefined;
        if (!self.config.headless) {
            self.clear_screen_mem();
            self.renderer = Renderer.init(self.config.scaling_factor);
        }    

        var quit = false;
        log_emu.info("Starting execution...", .{});
        const starttime_ms = std.time.milliTimestamp();
        while (!quit) {
            const sigint = @atomicLoad(bool, &sigint_received, std.builtin.AtomicOrder.acquire);
            quit = self.step(&frame_buffer) or sigint;
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
    }


    /// Like run but automatically detects infinite loop and stops execution
    pub fn run_ftest(self: *Emulator, limit_cycles: ?usize) !void {
        create_sigint_handler();
        self.cpu.reset();
        var frame_buffer: [3 * SCREEN_HEIGHT * SCREEN_WIDTH]u8 = undefined;
        var quit = false;
        
        var pc_prev: u16 = undefined;
        var cpu_state_prev: CPU = self.cpu.*;
        log_emu.info("Starting execution of functional test...", .{});
        
        const starttime_ms = std.time.milliTimestamp();
        while (!quit) {
            pc_prev = self.cpu.PC;
            quit = self.step(&frame_buffer) or sigint_received;
            if (pc_prev == self.cpu.PC) {
                if (self.cpu.PC == FTEST_SUCCESS_ADDR) {
                    log_emu .info("Functional test completed successfully! - Stopping execution...", .{});
                    self.cpu.print_state_compact();
                    break;
                } else {
                    log_emu.err("Functional test failed! - Stopping execution...", .{});
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
        const freq_i = @as(f64, @floatFromInt(self.instruction_count)) / @as(f64, @floatFromInt((runtime_ms * 1000)));

        
        // Casting to unsigned values because otherwise the formatter will display '+' signs
        var fmt_runtime_ms: u64 = @intCast(runtime_ms);
        
        const fmt_runtime_h: u16 = @intCast(@divTrunc(fmt_runtime_ms, 3600000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 3600000);
        const fmt_runtime_m: u6 = @intCast(@divTrunc(fmt_runtime_ms, 60000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 60000);
        const fmt_runtime_s: u6 = @intCast(@divTrunc(fmt_runtime_ms, 1000));
        fmt_runtime_ms = @rem(fmt_runtime_ms, 1000);

        const n_frames = blk: {
            if (self.renderer) |*r| {
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



    pub fn update_frame(self: *Emulator, frame_buffer: []u8) void {
        self.bus.write_io_ram(MemoryMap.raster_line_reg, 0); //Todo: This probably shouldn't be here long term, it is a quick and dirty hack to get kernal running for now,
        // as at some point it waits for the rasterline register to reach 0
        var bus = self.bus;
        for (MemoryMap.screen_mem_start..MemoryMap.screen_mem_end, MemoryMap.color_mem_start..MemoryMap.color_mem_end) |screen_mem_addr, color_mem_addr| {
            const screen_code = @as(u16, bus.read(@intCast(screen_mem_addr)));

            if (screen_code == 0x20) continue;

            const char_addr_start: u16 = (screen_code * 8);

            const char_count = screen_mem_addr - MemoryMap.screen_mem_start;

            // coordinates of upper left corner of char
            const char_x = (char_count % 40) * 8;
            const char_y = (char_count / 40) * 8;

            for (0..8) |char_row_idx| {
                const char_row_addr: u16 = @intCast(char_addr_start + char_row_idx);

                //const char_row_byte = self.bus.read(char_row_addr);
                const char_row_byte = self.bus.character_rom[char_row_addr];

                for (0..8) |char_col_idx| { // The leftmost pixel is represented by the most significant bit
                    const pixel: u1 = bitutils.get_bit_at(char_row_byte, @intCast(7 - char_col_idx));
                    const char_pixel_x = char_x + char_col_idx;
                    const char_pixel_y = char_y + char_row_idx;

                    const fbuf_idx: usize = (char_pixel_y * SCREEN_WIDTH + char_pixel_x) * 3;

                    if (pixel == 1) {
                        const color_code: u4 = @truncate(self.bus.read(@intCast(color_mem_addr)));
                        const color = colors.C64_COLOR_PALETTE[color_code];
                        frame_buffer[fbuf_idx] = color.r;
                        frame_buffer[fbuf_idx + 1] = color.g;
                        frame_buffer[fbuf_idx + 2] = color.b;
                    }
                }
            }
        }
    }
};

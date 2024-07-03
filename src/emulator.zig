const std = @import("std");
const raylib = @import("raylib.zig");

const CPU = @import("cpu/cpu.zig").CPU;
const Bus = @import("bus.zig").Bus;
const MemoryMap = @import("bus.zig").MemoryMap;
const bitutils = @import("cpu/bitutils.zig");
const colors = @import("colors.zig");
const Renderer = @import("renderer.zig").Renderer;

const SCREEN_WIDTH = @import("renderer.zig").SCREEN_WIDTH;
const SCREEN_HEIGHT = @import("renderer.zig").SCREEN_HEIGHT;
const BORDER_SIZE_X = @import("renderer.zig").BORDER_SIZE_X;
const BORDER_SIZE_Y = @import("renderer.zig").BORDER_SIZE_Y;

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
    end_at_cycle: ?usize = null,
    verbose: bool = false,
};

pub const Emulator = struct {
    bus: *Bus,
    cpu: *CPU,
    config: EmulatorConfig = .{},
    trace_config: DebugTraceConfig = .{},
    cycle_count: usize = 0,
    renderer: ?Renderer = null,

    pub fn init(allocator: std.mem.Allocator, config: EmulatorConfig) !Emulator {
        const bus = try allocator.create(Bus);
        bus.* = Bus.init();
        bus.enable_bank_switching = config.enable_bank_switching;
        std.log.debug("Emulator.init() called", .{});
        std.log.debug("Bank switching: {}", .{bus.enable_bank_switching});
        const cpu = try allocator.create(CPU);

        cpu.* = CPU.init(bus);
        var emulator: Emulator = .{
            .bus = bus,
            .cpu = cpu,
            .config = config,
        };

        if (!config.headless) {
            emulator.renderer = Renderer.init(config.scaling_factor);
        }

        cpu.print_debug_info = false; // This flag will be set based on the other parameters later in print_debug_output()

        return emulator;
    }

    pub fn init_graphics(self: *Emulator) !void {
        //try self.load_rom("data/c64_charset.bin", MemoryMap.character_rom_start);
        self.bus.write(MemoryMap.bg_color, colors.BG_COLOR);
        self.bus.write(MemoryMap.text_color, colors.TEXT_COLOR);
        self.bus.write(MemoryMap.frame_color, colors.FRAME_COLOR);
        try self.load_character_rom("data/c64_charset.bin");
        self.clear_color_mem();
    }

    pub fn init_c64(self: *Emulator) !void {
        try self.load_basic_rom();
        try self.load_kernal_rom();

        self.bus.write(0, 0x2F); // direction register
        self.bus.write(1, 0x37); // processor port

        // self.bus.write_16(0x00A0, 0x0800); // Points to BASIC start at $0801
        // self.bus.write_16(0x00A2, 0xA000); // Points to end of BASIC at $A000

        self.cpu.reset();
        try self.init_graphics();
        self.cpu.SP = 0xFF;
        std.log.info("C64 init procedure complete", .{});
    }

    fn load_basic_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/basic.bin", allocator);
        @memcpy(self.bus.basic_rom[0..], rom_data);
        allocator.free(rom_data);
        std.log.info("Loaded BASIC rom", .{});
    }

    fn load_character_rom(self: *Emulator, charset_path: []const u8) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data(charset_path, allocator);
        @memcpy(self.bus.character_rom[0..], rom_data);
        allocator.free(rom_data);
        std.log.info("Loaded charset '{s}' into character rom", .{charset_path});
    }

    pub fn set_trace_config(self: *Emulator, config: DebugTraceConfig) void {
        self.trace_config = config;
    }

    fn load_kernal_rom(self: *Emulator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data("data/kernal.bin", allocator);
        @memcpy(self.bus.kernal_rom[0..], rom_data);
        allocator.free(rom_data);
        std.log.info("Loaded KERNAL rom", .{});
    }

    pub fn deinit(self: Emulator, allocator: std.mem.Allocator) void {
        allocator.destroy(self.bus);
        allocator.destroy(self.cpu);
    }

    pub fn load_rom(self: *Emulator, rom_path: []const u8, offset: u16) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        const allocator = gpa.allocator();
        const rom_data = try load_file_data(rom_path, allocator);
        self.cpu.bus.write_continous(rom_data, offset);
        allocator.free(rom_data);
        std.log.info("Loaded rom data from file '{s}' at offset {X:0>4}", .{ rom_path, offset });
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
        self.cpu.clock_tick();
        self.print_debug_output();

        if (self.renderer) |r| {
            if (self.cycle_count % 10000 == 0) {
                self.clear_screen_text_area(frame_buffer);
                self.update_frame(frame_buffer);
                const border_color = blk: {
                    const color_code: u4 = @truncate(self.bus.read(MemoryMap.frame_color));
                    break :blk colors.C64_COLOR_PALETTE[color_code];
                };
                r.render_frame(frame_buffer, border_color);
            }

            if (raylib.WindowShouldClose()) {
                quit = true;
            }
        }

        self.cycle_count += 1;
        return quit;
    }

    pub fn run(self: *Emulator, limit_cycles: ?usize) !void {
        self.cpu.reset();

        var frame_buffer: [3 * SCREEN_HEIGHT * SCREEN_WIDTH]u8 = undefined;
        self.clear_screen_mem();
        var quit = false;

        while (!quit) {
            quit = self.step(&frame_buffer);
            if (limit_cycles) |max_cycles| {
                if (self.cycle_count >= max_cycles) break;
            }
        }

        std.log.info("{} cycles, {} instructions executed", .{ self.cpu._wait_cycles, self.cpu.cycle_count });
    }

    fn _print_debug_output(self: *Emulator) void {
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
    }

    fn print_debug_output(self: *Emulator) void {
        if (self.trace_config.enable_trace and self.cycle_count >= self.trace_config.start_at_cycle) {
            if (!self.trace_config.verbose) {
                self.cpu.print_debug_info = false;
                self.cpu.print_state_compact();
                return;
            } else if (self.trace_config.end_at_cycle) |end_cycle| {
                if (self.cycle_count > end_cycle) {
                    self.cpu.print_debug_info = false;
                    self.trace_config.enable_trace = false;
                    self._print_debug_output(); // print the output one last time to see the effect of the last instruction shown
                    return;
                }
            }
            if (self.trace_config.verbose) {
                self.cpu.print_debug_info = true;
                self._print_debug_output();
            }
        }
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

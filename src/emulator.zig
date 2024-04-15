const std = @import("std");
const CPU = @import("cpu/cpu.zig").CPU;
const DEBUG_CPU = @import("cpu/cpu.zig").DEBUG_CPU;
const Bus = @import("bus.zig").Bus;


fn load_file_data(rom_path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const data = try std.fs.cwd().readFileAlloc(allocator, rom_path, std.math.maxInt(usize));
    return data;
}



pub const Emulator = struct {

    bus: *Bus,
    cpu: *CPU,
    

    pub fn init(allocator: std.mem.Allocator) !Emulator {
        const bus = try allocator.create(Bus);
        bus.* = Bus.init();

        const cpu = try allocator.create(CPU);
        cpu.* = CPU.init(bus);
        
        return .{
            .bus = bus,
            .cpu = cpu
        };
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
    }



    pub fn run(self: *Emulator, limit_cycles: ?usize) void {
        
        self.cpu.reset();
        var count: usize = 0;
    
    
        while (!self.cpu.halt) {
            if(limit_cycles) |max_cycles| {
                if(count >= max_cycles) {
                    break;
                }
            }
            if(DEBUG_CPU) {
                self.cpu.bus.print_mem(0, 112);
            }
            
            self.cpu.clock_tick();
            count += 1;
        }
    }
      

};
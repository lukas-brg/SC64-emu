const std = @import("std");

pub const HookTrigger = union(enum) {
    PC: u16,
    at_cycle: usize,
    in_n_cycles: usize,
};

pub const Hook = struct {
    trigger: HookTrigger,
    callback: *fn(trigger: HookTrigger) void,
};


pub const HookService = struct {
    hooks: std.ArrayList(Hook),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator)  @This() {
        const list =  std.ArrayList(Hook).init(allocator);
        return HookService{
            .hooks = list,
            .allocator = allocator,
        };
    }

    // pub fn registerHook(self: *HookService, hook: Hook) void {
    //     // self.hooks.append(self.allocator, hook);
    // }

    // pub fn deinit(self: *HookService) void {
    //     self.hooks.deinit(self.allocator);

    // }
};
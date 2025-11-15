const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;
const runtime_info = @import("runtime_info.zig");

const MAX_HOOKS = 128;

var active_hooks: [MAX_HOOKS]Hook = undefined;
var hooks_count: usize = 0;

pub const HookTrigger = union(enum) {
    PC: u16,
    at_cycle: usize,
    in_n_cycles: usize,
    predicate: *const fn (emulator: *Emulator) bool,
};

pub const Hook = struct {
    trigger: HookTrigger,
    callback: *const fn (trigger: HookTrigger) void,
};

pub fn registerHook(hook: Hook) !void {
    if (hooks_count == MAX_HOOKS) return error.MaxHooksLimitReached;
    active_hooks[hooks_count] = hook;
    hooks_count += 1;
}

pub fn evalHooks(emu: *Emulator) void {
    var i: usize = 0;
    while (i < hooks_count) {
        const hook = &active_hooks[i];

        const does_trigger = switch (hook.trigger) {
            .in_n_cycles => |*cycles_left| blk: {
                if (cycles_left.* == 0) {
                    break :blk true;
                } else {
                    cycles_left.* -= 1;
                    break :blk false;
                }
            },
            .at_cycle => |c| runtime_info.current_cycle == c,
            .PC => |pc| pc == runtime_info.current_pc,
            .predicate => |p| p(emu),
        };

        if (does_trigger) {
            hook.callback(hook.trigger);
            active_hooks[i] = active_hooks[hooks_count - 1];
            hooks_count -= 1;
            continue;
        }

        i += 1;
    }
}

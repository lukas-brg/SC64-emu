const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;
const machine_state = @import("machine_state.zig");

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
    if (hooks_count >= MAX_HOOKS) return error.MaxHooksLimitReached;

    const _hook = switch (hook.trigger) {
        .in_n_cycles => |n| Hook{
            .trigger = .{ .at_cycle = machine_state.current_cycle + n },
            .callback = hook.callback,
        },
        else => hook,
    };
    active_hooks[hooks_count] = _hook;
    hooks_count += 1;
}

pub fn evalHooks(emu: *Emulator) void {
    var i: usize = 0;
    while (i < hooks_count) {
        const hook = &active_hooks[i];

        const does_trigger = switch (hook.trigger) {
            .at_cycle => |c| machine_state.current_cycle == c,
            .PC => |pc| pc == machine_state.current_pc,
            .predicate => |p| p(emu),
            else => unreachable,
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

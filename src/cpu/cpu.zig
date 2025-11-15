const std = @import("std");
const Bus = @import("../bus.zig").Bus;

const bitutils = @import("bitutils.zig");

const lookupOpcode = @import("opcodes.zig").lookupOpcode;
const OpcodeInfo = @import("opcodes.zig").OpcodeInfo;
const Instruction = @import("instruction.zig").Instruction;
const decodeOpcode = @import("instruction.zig").decodeOpcode;

const log_cpu = std.log.scoped(.cpu);


const RESET_VECTOR = 0xFFFC;
const IRQ_VECTOR = 0xFFFE;
const NMI_VECTOR = 0xFFFA;

pub const STACK_BASE_POINTER: u16 = 0x100;

pub const StatusFlag = enum(u3) {
    CARRY,
    ZERO,
    INTERRUPT_DISABLE,
    DECIMAL,
    BREAK,
    UNUSED,
    OVERFLOW,
    NEGATIVE,
};



const StatusRegister = packed struct(u8) {
    carry: u1 = 0,
    zero: u1 = 0,
    interrupt_disable: u1 = 1,
    decimal: u1 = 0,
    break_flag: u1 = 0,
    unused: u1 = 1,
    overflow: u1 = 0,
    negative: u1 = 0,

    pub inline fn toByte(self: StatusRegister) u8 {
        return @bitCast(self);
    }
    
    pub inline fn update(self: *StatusRegister, byte: u8) void {
        self.* = @bitCast(byte);
    }

    pub fn fromByte(value: u8) StatusRegister {
        return @bitCast(value);
    }

    pub inline fn updateNegative(self: *StatusRegister, result: u8) void {
        self.negative = bitutils.getBitAt(result, 7);
    }

    pub inline fn updateZero(self: *StatusRegister, result: u8) void {
        self.zero = @intFromBool(result == 0);
    }
};



pub const CPU = struct {
    /// Implementation of the 6502 microprocessor
    PC: u16,
    SP: u8,
    status: StatusRegister = .{},
    A: u8,
    X: u8,
    Y: u8,
    bus: *Bus,
    instruction_count: usize = 0,
    cycle_count: usize = 0,
    instruction_remaining_cycles: usize = 0,
    current_instruction: ?Instruction = null,
    halt: bool = false,
    print_debug_info: bool = true,
    mutex: std.Thread.Mutex = .{},

    pub fn init(bus: *Bus) CPU {
        const cpu = CPU{
            .PC = 0,
            .SP = 0xFF,
            .A = 0,
            .X = 0,
            .Y = 0,
            .bus = bus,
        };

        return cpu;
    }

    pub fn reset(self: *CPU) void {
        self.PC = self.bus.read16(RESET_VECTOR);
        log_cpu.debug("CPU Reset. Loaded PC from reset vector: {X:0>4}", .{self.PC});
    }

    pub fn irq(self: *CPU) void {
        if (self.status.interrupt_disable == 0) {
            self.mutex.lock();
            self.push16(self.PC);
            var status = self.status;
            status.break_flag = 0;
            self.push(status.toByte());
            self.PC = self.bus.read16(IRQ_VECTOR);
            self.mutex.unlock();
            //log_cpu.debug("IRQ", .{});
        } else {
            // log_cpu.debug("IRQ (masked)", .{});
        }
    }

    pub fn nmi(self: *CPU) void {
        self.push16(self.PC);
        var status = self.status;
        status.break_flag = 0;
        self.push(status.toByte());
        self.PC = self.bus.read16(NMI_VECTOR);
        log_cpu.debug("NMI", .{});
    }


    pub fn pop(self: *CPU) u8 {
        self.SP +%= 1;
        if (self.SP == 0) {
            log_cpu.debug("Stack overflow (Pop)  [PC={X:0>4}, OP={s}, Cycle={}, #Instruction={}]", .{
                self.current_instruction.?.instruction_addr,
                self.current_instruction.?.mnemonic,
                self.cycle_count,
                self.instruction_count,
            });
        } 
        return self.bus.read(STACK_BASE_POINTER + self.SP);
    }

    pub fn pop16(self: *CPU) u16 {
        return bitutils.combineBytes(self.pop(), self.pop());
    }

    pub fn push(self: *CPU, val: u8) void {
        self.bus.write(STACK_BASE_POINTER + self.SP, val);
        if (self.SP == 0) {
            log_cpu.debug("Stack overflow (Push) [PC={X:0>4}, OP={s}, Cycle={}, #Instruction={}]", .{
                self.current_instruction.?.instruction_addr,
                self.current_instruction.?.mnemonic,
                self.cycle_count,
                self.instruction_count,
            });
        }
        self.SP -%= 1;
    }
   
    pub fn push16(self: *CPU, val: u16) void {
        const high_byte: u8 = @intCast(val >> 8);
        self.push(high_byte);

        const low_byte: u8 = @intCast(val & 0xFF);
        self.push(low_byte);
    }

    fn fetchNextByte(self: CPU) u8 {
        return self.bus.read(self.PC);
    }

    pub fn setResetVector(self: *CPU, addr: u16) void {
        self.bus.write16(RESET_VECTOR, addr);
    }

    pub fn clockTick(self: *CPU) void {
        
        if (self.instruction_remaining_cycles > 0) {
            self.instruction_remaining_cycles -= 1;
        } else {
            self.step();
        }
    }


    /// Executes the next instruction in a single step
    pub fn step(self: *CPU) void {
        self.mutex.lock();
        const d_prev = self.status.decimal;
        const opcode = self.fetchNextByte();
        
        const opcode_info = lookupOpcode(opcode) orelse { 
            std.debug.panic("Illegal opcode {X:0>2} at {X:0>4}", .{ opcode, self.PC });
        };
       
        self.instruction_remaining_cycles = 0;
        var instruction = decodeOpcode(self, opcode_info);
        self.current_instruction = instruction;
        opcode_info.handler_fn(self, &instruction);
        self.instruction_remaining_cycles = instruction.cycles - 1;
        self.cycle_count += instruction.cycles;
        self.instruction_count += 1;
        const d_curr = self.status.decimal;
        self.mutex.unlock();

        if (d_curr != d_prev) {
            if (d_curr == 1) {
                log_cpu.debug("Decimal mode activated.   [PC={X:0>4}, OP={s}, Cycle={}, #Instruction={}]", .{
                    instruction.instruction_addr,
                    instruction.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
            } else {
                log_cpu.debug("Decimal mode deactivated. [PC={X:0>4}, OP={s}, Cycle={}, #Instruction={}]", .{
                    instruction.instruction_addr,
                    instruction.mnemonic,
                    self.cycle_count,
                    self.instruction_count,
                });
            }
        }
    }


};

const core = @import("../core.zig");
const assert = core.debug.assert;
const FixedBufferAllocator = core.heap.FixedBufferAllocator;
const Allocator = core.mem.Allocator;
const Mutex = core.Thread.Mutex;

const builtin = @import("builtin");

const Fiber = @This();

pub const Options = struct {
    allocator: Allocator,
    stack_size: ?usize = null,
};
pub fn spawn(options: Options, comptime func: anytype, args: anytype) !Fiber {
    return .{ .impl = try Impl.spawn(options, func, args) };
}

pub fn convertCurrentThreadToFiber(allocator: Allocator) !Fiber {
    return .{ .impl = try Impl.convertCurrentThreadToFiber(allocator) };
}

pub fn switchTo(self: Fiber) void {
    self.impl.switchTo();
}

pub fn yield() void {
    Impl.yield();
}

const Impl = switch (builtin.cpu.arch) {
    .aarch64 => AArch64Impl,
    else => @compileError("Fiber is not supported on CPU Arch"),
};
impl: Impl,

threadlocal var active: ?Impl = null;
threadlocal var original: ?Impl = null;

const AArch64Impl = struct {
    const register_count = 22;
    const Instance = struct {
        allocator: Allocator,
        registers: [register_count]usize,
    };

    instance: *Instance,

    comptime {
        asm (
            \\.global _hammer_stack_swap
            \\_hammer_stack_swap:
            \\  stp lr, fp, [x0, #0*8]
            \\  stp d8, d9, [x0, #2*8]
            \\  stp d10, d11, [x0, #4*8]
            \\  stp d12, d13, [x0, #6*8]
            \\  stp d14, d15, [x0, #8*8]
            \\  stp x19, x20, [x0, #10*8]
            \\  stp x21, x22, [x0, #12*8]
            \\  stp x23, x24, [x0, #14*8]
            \\  stp x25, x26, [x0, #16*8]
            \\  stp x27, x28, [x0, #18*8]
            \\
            \\  mov x9, sp
            \\  str x9, [x0, #20*8]
            \\
            \\  ldr x9, [x1, #20*8]
            \\  mov sp, x9
            \\
            \\  ldp x27, x28, [x1, #18*8]
            \\  ldp x25, x26, [x1, #16*8]
            \\  ldp x23, x24, [x1, #14*8]
            \\  ldp x21, x22, [x1, #12*8]
            \\  ldp x19, x20, [x1, #10*8]
            \\  ldp d14, d15, [x1, #8*8]
            \\  ldp d12, d13, [x1, #6*8]
            \\  ldp d10, d11, [x1, #4*8]
            \\  ldp d8, d9, [x1, #2*8]
            \\  ldp lr, fp, [x1], #0*8
            \\  
            \\  ret
        );
    }

    extern fn hammer_stack_swap(
        noalias current: [*]usize,
        noalias new: [*]usize,
    ) void;

    fn spawn(options: Options, comptime func: anytype, args: anytype) !Impl {
        const allocator = options.allocator;

        const default_stack_size = 1024 * 1024 * 1024;
        const stack_size = options.stack_size orelse default_stack_size;

        const Args = @TypeOf(args);
        const Closure = struct {
            instance: Instance,
            args: Args,

            fn entry() callconv(.C) noreturn {
                const instance = (active orelse unreachable).instance;
                const closure: *@This() = @fieldParentPtr("instance", instance);

                @call(.auto, func, closure.args);
                Fiber.yield();

                unreachable;
            }
        };
        const alloc_size = @sizeOf(Closure) + stack_size;
        const memory = try allocator.allocWithOptions(u8, alloc_size, @alignOf(Closure), null);
        var buffer = FixedBufferAllocator.init(memory);
        const buffer_allocator = buffer.allocator();
        const closure = try buffer_allocator.create(Closure);
        const stack = try buffer_allocator.alloc(u8, stack_size);

        closure.args = args;
        closure.instance.allocator = allocator;
        closure.instance.registers[0] = @intFromPtr(&Closure.entry);
        closure.instance.registers[20] = @intFromPtr(stack.ptr + stack.len);

        return .{ .instance = &closure.instance };
    }

    fn convertCurrentThreadToFiber(allocator: Allocator) !Impl {
        assert(active == null and original == null);

        const instance = try allocator.create(Instance);
        instance.* = .{
            .allocator = allocator,
            .registers = undefined,
        };
        const impl: Impl = .{ .instance = instance };
        active = impl;
        original = impl;
        return impl;
    }

    fn switchTo(self: Impl) void {
        assert(active != null and active.?.instance != self.instance);

        const last = active.?;
        active = self;
        hammer_stack_swap(@ptrCast(&last.instance.registers[0]), @ptrCast(&self.instance.registers[0]));
    }

    fn yield() void {
        assert(original != null and active != null and original.?.instance != active.?.instance);
        original.?.switchTo();
    }
};

const core = @import("core.zig");
const mem = core.mem;
const Allocator = mem.Allocator;
const enums = core.enums;
const Thread = core.Thread;
const Atomic = core.atomic.Value;

pub const MPMC = @import("Scheduler/mpmc.zig").MPMC;
pub const Counter = @import("Scheduler/Counter.zig");

const Scheduler = @This();

allocator: mem.Allocator,
state: Atomic(State),
threads: []Thread.Id,
queues: [Priority.count]MPMC(Task),

const Task = struct {
    ptr: *anyopaque,
    execute: *const fn (ptr: *anyopaque) void,
};

pub const State = enum(u8) {
    starting,
    running,
    shutdown,
};

pub const Priority = enum(u8) {
    high,
    normal,
    low,

    pub const count = enums.values(@This()).len;
};

pub const Options = struct {
    allocator: Allocator,
    worker_count: ?usize = null,
    fiber_count: u32 = 512,
    waiting_count: u32 = 1024,
    queue_counts: [Priority.count]u32 = .{
        256,
        512,
        1024,
    },
};

pub fn init(scheduler: *Scheduler, options: Options) !void {
    const allocator = options.allocator;

    // Acquire all the memory and initialize the structure
    const thread_count = options.worker_count orelse @max(1, Thread.getCpuCount() catch 1);
    const threads = try allocator.alloc(Thread.Id, thread_count);
    scheduler.* = .{
        .allocator = allocator,
        .state = Atomic(State).init(.starting),
        .threads = threads,
        .queues = .{
            try MPMC(Task).init(allocator, options.queue_counts[@intFromEnum(Priority.high)]),
            try MPMC(Task).init(allocator, options.queue_counts[@intFromEnum(Priority.normal)]),
            try MPMC(Task).init(allocator, options.queue_counts[@intFromEnum(Priority.low)]),
        },
    };

    // Initialize the worker threads. The workers need to update their id in their scheduler.threads
    // slot. After that is done then the threads are ready to work.
    var ready_count = Atomic(usize).init(1);
    scheduler.threads[0] = Thread.getCurrentId();
    for (1..thread_count) |i| {
        const thread = try Thread.spawn(.{}, worker, .{ scheduler, &ready_count, i });
        thread.detach();
    }

    // Wait until all threads have marked themselves as ready
    while (true) {
        if (ready_count.load(.acquire) == thread_count) {
            break;
        }
    }

    // Update the schedule state to running so workers can get to it!
    scheduler.state.store(State.running, .release);
}

fn worker(scheduler: *Scheduler, ready_count: *Atomic(usize), index: usize) void {
    // Register self with the scheduler and then mark as ready
    const id = Thread.getCurrentId();
    scheduler.threads[index] = id;
    _ = ready_count.fetchAdd(1, .acq_rel);

    // Loop until the scheduler is being shut down
    while (true) {
        // While the scheduler is starting early out
        const state = scheduler.state.load(.acquire);
        switch (state) {
            .starting => continue,
            .shutdown => break,
            else => {},
        }

        // Execute the jobs of highest priority first and if one is executed rerun the
        // work loop.
        // TODO: Pick up complete work and resume the fiber
        for (0..Priority.count) |i| {
            const job = scheduler.queues[i].pop();
            if (job != null) {
                job.?.execute(job.?.ptr);
                break;
            }
        }
    }
}

pub fn enqueue(self: *Scheduler, priority: Priority, comptime func: anytype, args: anytype) !void {
    // Declare the Closure that will be allocated and queued as a task
    const Args = @TypeOf(args);
    const Closure = struct {
        args: Args,
        scheduler: *Scheduler,

        fn executeFn(ptr: *anyopaque) void {
            const closure: *@This() = @ptrCast(@alignCast(ptr));
            @call(.auto, func, closure.args);
            closure.scheduler.allocator.destroy(closure);
        }
    };

    // Allocate the closure and fill it out
    const closure = try self.allocator.create(Closure);
    closure.* = .{
        .args = args,
        .scheduler = self,
    };

    // Push into the queue
    _ = self.queues[@intFromEnum(priority)].push(.{
        .ptr = closure,
        .execute = Closure.executeFn,
    });
}

pub const Work = struct {
    ptr: *anyopaque,
    is_complete: *const fn (ptr: *anyopaque) bool,

    pub fn isComplete(self: @This()) bool {
        return self.is_complete(self.ptr);
    }
};

const WaitingWork = struct {
    const Inner = struct {
        work: Work,
        fiber: usize,
        thread: ?Thread.Id,
    };
    mutex: Thread.Mutex,
    inner: ?Inner,
};

pub fn waitFor(self: *Scheduler, work: Work) void {
    _ = self;
    if (work.isComplete()) {
        return;
    }

    // TODO: Actually implement a fiber based job system
    while (!work.isComplete()) {}
}

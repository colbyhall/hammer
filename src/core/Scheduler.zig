const core = @import("core.zig");
const assert = core.debug.assert;
const mem = core.mem;
const Allocator = mem.Allocator;
const enums = core.enums;
const Thread = core.Thread;
const Atomic = core.atomic.Value;

pub const MPMC = @import("Scheduler/mpmc.zig").MPMC;
pub const Fiber = @import("Scheduler/Fiber.zig");
pub const Counter = @import("Scheduler/Counter.zig");

const Scheduler = @This();

allocator: mem.Allocator,
state: Atomic(State),
threads: []Thread.Id,
queues: [Priority.count]MPMC(Task),
fibers: []Fiber,
free_fibers: MPMC(u32),
waiting_work: []WaitingWork,

// This value is cached so yielding threads know what scheduler relative fiber they're running
threadlocal var fiber_index: ?u32 = 0;

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
    const thread_count = options.worker_count orelse @max(1, Thread.getCpuCount() catch 1);

    const fibers = try allocator.alloc(Fiber, options.fiber_count);
    for (thread_count..options.fiber_count) |i| {
        fibers[i] = try Fiber.spawn(.{ .allocator = allocator }, workerFiber, .{ scheduler, @as(u32, @intCast(i)) });
    }

    var free_fibers = try MPMC(u32).init(allocator, options.fiber_count);
    for (thread_count..options.fiber_count) |i| {
        _ = free_fibers.push(@intCast(i));
    }

    const waiting_work = try allocator.alloc(WaitingWork, options.waiting_count);
    for (waiting_work) |*w| {
        w.inner = null;
        w.mutex = .{};
    }

    fibers[0] = try Fiber.convertCurrentThreadToFiber(allocator);
    fiber_index = 0;

    // Acquire all the memory and initialize the structure
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
        .fibers = fibers,
        .free_fibers = free_fibers,
        .waiting_work = waiting_work,
    };

    // Initialize the worker threads. The workers need to update their id in their scheduler.threads
    // slot. After that is done then the threads are ready to work.
    var ready_count = Atomic(usize).init(1);
    scheduler.threads[0] = Thread.getCurrentId();
    for (1..thread_count) |i| {
        const thread = try Thread.spawn(.{}, workerThread, .{ scheduler, &ready_count, @as(u32, @intCast(i)) });
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

fn workerThread(scheduler: *Scheduler, ready_count: *Atomic(usize), index: u32) void {
    // Register self with the scheduler and then mark as ready
    const id = Thread.getCurrentId();
    scheduler.threads[index] = id;
    scheduler.fibers[index] = Fiber.convertCurrentThreadToFiber(scheduler.allocator) catch unreachable;
    fiber_index = index;
    _ = ready_count.fetchAdd(1, .acq_rel);

    scheduler.doWork(index);
}

fn workerFiber(scheduler: *Scheduler, index: u32) void {
    scheduler.doWork(index);
}

fn doWork(scheduler: *Scheduler, original_fiber_index: u32) void {
    // Loop until the scheduler is being shut down
    outer: while (true) {
        // While the scheduler is starting early out
        const state = scheduler.state.load(.acquire);
        switch (state) {
            .starting => continue,
            .shutdown => break,
            else => {},
        }

        // Execute the jobs from highest to lowest priority and if one is executed rerun the
        // outer loop.
        var job = scheduler.queues[@intFromEnum(Priority.high)].pop();
        if (job != null) {
            job.?.execute(job.?.ptr);
            continue;
        }

        // Look for work to that is complete so that we can resume the yielded fiber
        for (scheduler.waiting_work) |*w| {
            // For now just skip alread locked work because outer will always loop back around. This may introduce latency
            // between work completion and resuming the fiber that is yielded waiting on it.
            if (!w.mutex.tryLock()) continue;

            // Skip if no work is listed
            if (w.inner == null) {
                w.mutex.unlock();
                continue;
            }

            // Skip if the work isn't completed
            const inner = &w.inner.?;
            if (!inner.work.isComplete()) {
                w.mutex.unlock();
                continue;
            }

            // We can only switch to a fiber if...
            // A. The work required that the it resumes back on the thread that yielded to it and this is that thread
            // or
            // B. No thread requirement was added
            const switch_to_fiber = (inner.thread != null and inner.thread.? == Thread.getCurrentId()) or inner.thread == null;
            if (switch_to_fiber) {
                assert(original_fiber_index == fiber_index.?);

                // Update the current fiber index to the fiber we're resuming work on
                fiber_index = inner.fiber;

                // Reset the waiting work slot and unlock the mutex
                w.inner = null;
                w.mutex.unlock();

                // Add this fiber back to the free list so it can be used by threads waiting for their work to be complete
                // TODO: This is possibly a race condition because the active fiber could be
                // popped from free fibers before active fiber has switched.
                _ = scheduler.free_fibers.push(original_fiber_index);
                scheduler.fibers[inner.fiber].switchTo();

                continue :outer;
            } else {
                w.mutex.unlock();
            }
        }

        job = scheduler.queues[@intFromEnum(Priority.normal)].pop();
        if (job != null) {
            job.?.execute(job.?.ptr);
            continue;
        }

        job = scheduler.queues[@intFromEnum(Priority.low)].pop();
        if (job != null) {
            job.?.execute(job.?.ptr);
            continue;
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
    // TODO: Use an atomic ring allocator for closures so they are cheap and never have to be freed
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

/// Interface for anything that can be considered complete.
pub const Work = struct {
    ptr: *anyopaque,

    /// Returns true if the underlying state is complete. Must be thread safe.
    is_complete: *const fn (ptr: *anyopaque) bool,

    pub fn isComplete(self: @This()) bool {
        return self.is_complete(self.ptr);
    }
};

const WaitingWork = struct {
    const Inner = struct {
        work: Work,
        fiber: u32,
        thread: ?Thread.Id,
    };
    mutex: Thread.Mutex,
    inner: ?Inner,
};

/// Yields this fibers execution and switches to an available worker so task can be completed
/// while the original fiber waits.
pub fn yieldUntilComplete(self: *Scheduler, work: Work) void {
    if (work.isComplete()) return;

    outer: while (true) {
        for (self.waiting_work) |*w| {
            if (!w.mutex.tryLock()) continue;
            defer w.mutex.unlock();
            if (w.inner != null) {
                continue;
            }
            w.inner = .{
                .work = work,
                .fiber = fiber_index.?,
                .thread = Thread.getCurrentId(),
            };
            break :outer;
        }
    }

    while (!work.isComplete()) {
        const fiber = self.free_fibers.pop() orelse continue;
        fiber_index = fiber;
        self.fibers[fiber].switchTo();
    }
    assert(work.isComplete());
}

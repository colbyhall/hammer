const core = @import("../core.zig");
const Atomic = core.atomic.Value;
const Work = core.Scheduler.Work;

const Counter = @This();

target: u32,
value: Atomic(u32),

pub fn init(target: u32, initial_value: u32) Counter {
    return .{
        .target = target,
        .value = Atomic(u32).init(initial_value),
    };
}

pub fn increment(self: *Counter) bool {
    return self.value.fetchAdd(1, .acq_rel) + 1 == self.target;
}

pub fn work(self: *Counter) Work {
    return .{
        .ptr = self,
        .is_complete = &isComplete,
    };
}

fn isComplete(ptr: *anyopaque) bool {
    const self: *Counter = @ptrCast(@alignCast(ptr));
    return self.target == self.value.load(.acquire);
}

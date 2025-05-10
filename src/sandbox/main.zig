const core = @import("core");
const mem = core.mem;
const math = core.math;
const Vector2 = core.math.Vector2;

const Scheduler = core.Scheduler;
const Fiber = Scheduler.Fiber;
const Counter = Scheduler.Counter;

pub fn main() !void {
    var gpa = core.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var scheduler: Scheduler = undefined;
    try scheduler.init(.{ .allocator = allocator });

    const count = 32;
    var counter = Counter.init(count, 0);
    for (0..count) |_| {
        try scheduler.enqueue(.low, doThing, .{&counter});
    }

    scheduler.yieldUntilComplete(counter.work());
}

fn doThing(counter: *Counter) void {
    defer _ = counter.increment();
    core.debug.print("Hello World {}\n", .{core.Thread.getCurrentId()});
}

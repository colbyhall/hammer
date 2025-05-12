const core = @import("core");
const mem = core.mem;
const math = core.math;
const Vector2 = core.math.Vector2;
const Scheduler = core.Scheduler;
const Fiber = Scheduler.Fiber;
const Counter = Scheduler.Counter;

const gpu = @import("gpu");
const metal = gpu.drivers.metal;
const MetalDevice = metal.Device;
const MetalBuffer = metal.Buffer;
const Buffer = gpu.Buffer;

pub fn main() !void {
    var gpa = core.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    if (false) {
        var scheduler: Scheduler = undefined;
        try scheduler.init(.{ .allocator = allocator });

        const count = 1024 * 1024;
        var counter = Counter.init(count, 0);
        for (0..count) |_| {
            try scheduler.enqueue(.low, doThing, .{&counter});
        }

        scheduler.yieldUntilComplete(counter.asWork());
    }

    // Initialize the metal device
    var metal_device = try MetalDevice.init(.{ .allocator = allocator });
    defer metal_device.deinit();
    const device = metal_device.device();

    // Create a buffer from a given value
    const value: usize = 420;
    const data = mem.asBytes(&value);
    const buffer = try Buffer.initUpload(data, .{
        .device = device,
        .usage = .{
            .transfer_src = true,
        },
        .size = data.len,
    });
    defer buffer.deinit();
}

fn doThing(counter: *Counter) void {
    defer _ = counter.increment();
    core.debug.print("Hello World {}\n", .{core.Thread.getCurrentId()});
}

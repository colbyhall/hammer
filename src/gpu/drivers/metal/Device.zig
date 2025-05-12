const core = @import("core");
const assert = core.debug.assert;
const mem = core.mem;
const Allocator = mem.Allocator;

const gpu = @import("../../gpu.zig");
const Device = gpu.Device;
const Buffer = gpu.Buffer;
const Pool = gpu.Pool;

const metal = gpu.drivers.metal;
const api = metal.api;
const MetalBuffer = metal.Buffer;

const MetalDevice = @This();

handle: api.metal_device_t,

buffers: Pool(MetalBuffer),

pub const Options = struct {
    allocator: Allocator,

    buffer_capacity: u32 = 2048,
};
pub fn init(options: Options) !MetalDevice {
    const buffers = try Pool(MetalBuffer).init(options.allocator, options.buffer_capacity);

    var handle: api.metal_device_t = api.METAL_NULL_HANDLE;
    const result = api.metal_init_device(&handle);
    assert(result == api.METAL_RESULT_OK);

    return .{ .handle = handle, .buffers = buffers };
}

pub fn deinit(self: *MetalDevice) void {
    api.metal_release(self.handle);
}

pub fn device(self: *MetalDevice) Device {
    return .{
        .ptr = self,
        .vtable = &.{
            .initUploadBuffer = &MetalBuffer.initUpload,
            .initStorageBuffer = &MetalBuffer.initStorage,
        },
    };
}

const core = @import("core");
const assert = core.debug.assert;

const gpu = @import("../../gpu.zig");
const Device = gpu.Device;
const Buffer = gpu.Buffer;

const metal = gpu.drivers.metal;
const api = metal.api;
const MetalDevice = metal.Device;

const MetalBuffer = @This();

owner: Device,
index: usize,
handle: api.metal_buffer_t,

pub fn initUpload(ptr: *anyopaque, bytes: []const u8, options: Buffer.Options) Buffer {
    const metal_device: *MetalDevice = @ptrCast(@alignCast(ptr));

    var handle: api.metal_buffer_t = api.METAL_NULL_HANDLE;
    const metal_buffer_options = api.metal_buffer_options_t{
        .device = metal_device.handle,
        .size = @intCast(options.size),
    };
    const result = api.metal_init_upload_buffer(&handle, bytes.ptr, &metal_buffer_options);
    assert(result == api.METAL_RESULT_OK);

    const metal_buffer = MetalBuffer{
        .owner = metal_device.device(),
        .handle = handle,
        .index = undefined,
    };
    const index = metal_device.buffers.add(metal_buffer) orelse unreachable;
    const buffer_ptr = &(metal_device.buffers.items[index].?);
    buffer_ptr.index = index;

    return .{
        .ptr = buffer_ptr,
        .vtable = &.{
            .deinit = &deinit,
        },
    };
}

pub fn initStorage(ptr: *anyopaque, options: Buffer.Options) Buffer {
    const metal_device: *MetalDevice = @ptrCast(@alignCast(ptr));

    var handle: api.metal_buffer_t = api.METAL_NULL_HANDLE;
    const metal_buffer_options = api.metal_buffer_options_t{
        .device = metal_device.handle,
        .size = @intCast(options.size),
    };
    const result = api.metal_init_storage_buffer(&handle, &metal_buffer_options);
    assert(result == api.METAL_RESULT_OK);

    const metal_buffer = MetalBuffer{
        .owner = metal_device.device(),
        .handle = handle,
        .index = undefined,
    };
    const index = metal_device.buffers.add(metal_buffer) orelse unreachable;
    const buffer_ptr = &(metal_device.buffers.items[index].?);
    buffer_ptr.index = index;

    return .{
        .ptr = buffer_ptr,
        .vtable = &.{
            .deinit = &deinit,
        },
    };
}

pub fn deinit(ptr: *anyopaque) void {
    const metal_buffer: *MetalBuffer = @ptrCast(@alignCast(ptr));
    const metal_device: *MetalDevice = @ptrCast(@alignCast(metal_buffer.owner.ptr));

    api.metal_release(metal_buffer.handle);

    const ok = metal_device.buffers.remove(metal_buffer.index);
    assert(ok);
}

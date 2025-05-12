const core = @import("core");
const assert = core.debug.assert;
const math = core.math;
const Vector3 = math.Vector3;

const gpu = @import("gpu.zig");
const Device = gpu.Device;

const Texture = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (*anyopaque) void,
};

pub const Usage = packed struct {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    sampled: bool = false,
    color_attachment: bool = false,
    depth_attachment: bool = false,
    swapchain: bool = false,
};

pub const Format = enum {
    unknown,
    r_u8,

    rgba_u8,
    rgba_u8_srgb,

    rgba_f16,
    rgba_f32,

    bgra_u8_srgb,

    depth16,
    depth32_stencil8,
};

pub const Size = Vector3(u32);

pub const Options = struct {
    device: Device,

    usage: Usage,
    format: Format,
    size: Size,
    mip_levels: u32 = 1,
};
pub fn init(options: Options) Texture {
    assert(options.size.x >= 1 and options.size.y >= 1 and options.size.z >= 1);
    assert(options.mip_levels >= 1);
}

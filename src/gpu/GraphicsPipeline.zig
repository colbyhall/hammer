const core = @import("core");

const gpu = @import("gpu.zig");
const Format = gpu.Texture.Format;
const Device = gpu.Device;

const GraphicsPipeline = @This();

pub const DrawMode = enum {
    fill,
    line,
    point,
};

pub const CullMode = enum {
    none,
    front,
    back,
};

pub const Winding = enum {
    clockwise,
    counter_clockwise,
};

pub const CompareOp = enum {
    never,
    less,
    equal,
    not_equal,
    less_or_equal,
    greater,
    greater_or_equal,
    always,
};

pub const BlendOp = enum {
    add,
    subtract,
    reverse_subtract,
    min,
    max,
};

pub const BlendFactor = enum {
    zero,
    one,

    src_color,
    one_minus_src_color,
    dst_color,
    one_minus_dst_color,

    src_alpha,
    one_minus_src_alpha,
};

pub const ColorComponents = packed struct {
    r: bool,
    g: bool,
    b: bool,
    a: bool,

    pub const rgba: @This() = .{
        .r = true,
        .g = true,
        .b = true,
        .a = true,
    };
};

pub const ColorAttachment = struct {
    pub const Blending = struct {
        src_color_factor: BlendFactor = .one,
        dst_color_factor: BlendFactor = .one,
        color_op: BlendOp = .add,

        src_alpha_factor: BlendFactor = .one,
        dst_alpha_factor: BlendFactor = .one,
        alpha_op: BlendOp = .add,
    };

    format: Format,
    blending: ?Blending = null,
    write_mask: ColorComponents = .rgba,
};

pub const DepthAttachment = struct {
    format: Format,

    depth_test: bool = false,
    depth_write: bool = false,
    compare_op: CompareOp = .always,
};

pub const Options = struct {
    device: Device,

    // TODO: Shaders

    color_attachments: []ColorAttachment,
    depth_attachment: ?DepthAttachment = null,

    draw_mode: DrawMode = .fill,
    line_width: f32 = 1,
    cull_mode: CullMode = .none,
    winding: Winding = .clockwise,
};
pub fn spawn(options: Options) !GraphicsPipeline {
    _ = options;
    unreachable;
}

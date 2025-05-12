const gpu = @import("gpu.zig");
const Buffer = gpu.Buffer;
const Texture = gpu.Texture;
const GraphicsPipeline = gpu.GraphicsPipeline;

const Device = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    initUploadBuffer: *const fn (*anyopaque, []const u8, Buffer.Options) Buffer,
    initStorageBuffer: *const fn (*anyopaque, Buffer.Options) Buffer,
};

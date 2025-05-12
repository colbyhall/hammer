pub const Device = @import("metal/Device.zig");
pub const Buffer = @import("metal/Buffer.zig");

pub const api = @cImport({
    @cInclude("metal.h");
});

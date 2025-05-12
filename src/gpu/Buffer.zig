const core = @import("core");
const assert = core.debug.assert;

const gpu = @import("gpu.zig");
const Device = gpu.Device;

const Buffer = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (ptr: *anyopaque) void,
};

pub const Usage = packed struct {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    vertex: bool = false,
    index: bool = false,
    constant: bool = false,
};

pub const Options = struct {
    device: Device,
    usage: Usage,
    size: usize,
};

pub fn initUpload(bytes: []const u8, options: Options) !Buffer {
    assert(options.usage.transfer_src);
    assert(options.size == bytes.len);
    return options.device.vtable.initUploadBuffer(options.device.ptr, bytes, options);
}

pub fn initStorage(options: Options) !Buffer {
    assert(options.usage.transfer_dst);
    return options.device.vtable.initStorageBuffer(options.device.ptr, options);
}

pub fn deinit(self: Buffer) void {
    self.vtable.deinit(self.ptr);
}

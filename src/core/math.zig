const core = @import("core.zig");
const Type = core.builtin.Type;

const std = @import("std");
const math = std.math;

pub const deg_per_rad = math.deg_per_rad;
pub const rad_per_deg = math.rad_per_deg;
pub const pi = math.pi;
pub const tau = math.tau;

pub fn isNumber(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        Type.int, Type.float => true,
        else => false,
    };
}

pub fn checkIsNumber(comptime T: type) void {
    if (!isNumber(T)) {
        @compileError("T is not a number. A number is a float or an int.");
    }
}

pub fn Vector2(comptime T: type) type {
    checkIsNumber(T);
    return struct {
        x: T,
        y: T,
    };
}

pub fn Vector3(comptime T: type) type {
    checkIsNumber(T);
    return struct {
        x: T,
        y: T,
        z: T,
    };
}

pub fn Vector4(comptime T: type) type {
    checkIsNumber(T);
    return struct {
        x: T,
        y: T,
        z: T,
        w: T,
    };
}

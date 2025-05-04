const core = @import("core");
const math = core.math;
const Vector2 = core.math.Vector2;

pub fn main() void {
    const foo = Vector2(i32){ .x = 120, .y = 123 };
    core.debug.print("Hello World {}\n", .{foo});
}

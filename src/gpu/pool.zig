const core = @import("core");
const assert = core.debug.assert;
const MPMC = core.Scheduler.MPMC;
const mem = core.mem;
const Allocator = mem.Allocator;

pub fn Pool(comptime Impl: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        items: []?Impl,
        free_list: MPMC(u32),

        pub fn init(allocator: Allocator, size: usize) !Self {
            const items = try allocator.alloc(?Impl, size);
            for (items) |*item| {
                item.* = null;
            }
            var free_list = try MPMC(u32).init(allocator, size);
            for (0..size) |i| {
                _ = free_list.push(@intCast(i));
            }
            return .{
                .allocator = allocator,
                .items = items,
                .free_list = free_list,
            };
        }

        pub fn add(self: *Self, item: Impl) ?usize {
            const index: usize = @intCast(self.free_list.pop() orelse return null);
            assert(self.items[index] == null);
            self.items[index] = item;
            return index;
        }

        pub fn remove(self: *Self, index: usize) bool {
            if (index >= self.items.len) return false;

            if (self.items[index] == null) return false;

            self.items[index] = null;
            const ok = self.free_list.push(@intCast(index));
            assert(ok);

            return true;
        }
    };
}

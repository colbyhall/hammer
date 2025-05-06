const core = @import("../core.zig");
const Allocator = core.mem.Allocator;
const Mutex = core.Thread.Mutex;

pub fn MPMC(comptime T: type) type {
    return struct {
        pub const Cell = struct {
            sequence: usize,
            value: T,
        };

        mutex: Mutex,
        buffer: []Cell,
        enqueue_pos: usize,
        dequeue_pos: usize,

        pub fn init(allocator: Allocator, capacity: usize) !@This() {
            core.debug.assert(capacity >= 2 and (capacity & (capacity - 1) == 0));

            const buffer = try allocator.alloc(Cell, capacity);
            for (buffer, 0..) |*b, i| {
                b.sequence = i;
                b.value = undefined;
            }
            return .{
                .mutex = Mutex{},
                .buffer = buffer,
                .enqueue_pos = 0,
                .dequeue_pos = 0,
            };
        }

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            allocator.free(self.buffer);
        }

        pub fn push(self: *@This(), value: T) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            const pos = self.enqueue_pos;
            const cell = &self.buffer[pos & (self.buffer.len - 1)];
            const seq = cell.sequence;
            const dif = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos));
            if (dif == 0) {
                self.enqueue_pos += 1;
                cell.value = value;
                cell.sequence = pos + 1;
                return true;
            }

            return false;
        }

        pub fn pop(self: *@This()) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            const pos = self.dequeue_pos;
            const cell = &self.buffer[pos & (self.buffer.len - 1)];
            const seq = cell.sequence;
            const dif = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos + 1));
            if (dif == 0) {
                self.dequeue_pos += 1;
                const result = cell.value;
                cell.value = undefined;
                cell.sequence = pos + self.buffer.len;
                return result;
            }

            return null;
        }
    };
}

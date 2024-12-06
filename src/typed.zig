const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Typed(comptime T: type) type {
    return struct {
        const Self = @This();

        // We expect the type to have
        // init(Allocator) and deinit(Allocator) methods.
        value: T,

        pub fn parse(allocator: Allocator, reader: anytype) !Self {
            _ = reader;
            const parsed: Self = .{.value = T.init(allocator)};
            return parsed;
        }

        pub fn deinit(self: *Self) void {
            self.value.deinit();
        }
    };
}
const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

pub fn stringify(
    allocator: Allocator,
    writer: std.io.AnyWriter,
    comptime T: type,
    options: struct {}
) !void {
    _ = options;
    const arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

}
const std = @import("std");
const shared = @import("shared.zig");
const Stream = @import("stream.zig");
const Value = @import("value.zig").Value;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Error = shared.ParseError;
const ParseOptions = shared.ParseOptions;

const Self = @This();

allocator: Allocator,
stream: *Stream,

depth: usize = 0,
max_depth: usize,

// Parses untyped JSON,
// returning ownership of a Value that the user is responsible for cleaning up.
pub fn parse(
    allocator: Allocator,
    reader: std.io.AnyReader,
    options: ParseOptions
) Error!*Value {
    var stream = try Stream.from(allocator, reader);
    errdefer stream.cleanup();
    defer stream.deinit();

    var parser = Self{.allocator = allocator, .stream = &stream, .max_depth = options.max_depth};
    return try parser.parseValue();
}

fn incrementDepth(self: *Self, increment: usize) void {
    self.depth += increment;
    if (self.depth > self.max_depth) std.debug.panic("Max supported depth of {any} exceeded\n", .{self.max_depth});
}

fn decrementDepth(self: *Self, decrement: usize) void {
    const new_depth = @subWithOverflow(self.depth, decrement);
    std.debug.assert(new_depth[1] != 1); // Overflows shouldn't happen.
    self.depth = new_depth[0];
}

// Parse the next Value.
pub fn parseValue(self: *Self) Error!*Value {
    const next = try self.stream.advance();
    switch (next.kind) {
        .left_bracket => {
            var value = try Value.from(self.allocator, ArrayList(*Value).init(self.allocator));
            errdefer value.deinit(self.allocator);
            self.incrementDepth(1);
            while (!try self.stream.match(.right_bracket)) {
                if (value.array.items.len != 0) _ = try self.stream.eat(.comma);
                try value.array.append(try self.parseValue());
            }
            _ = try self.stream.eat(.right_bracket);
            self.decrementDepth(1);
            return value;
        },
        .left_brace => {
            var value = try Value.from(self.allocator, StringHashMap(*Value).init(self.allocator));
            errdefer value.deinit(self.allocator);
            self.incrementDepth(1);
            while (!try self.stream.match(.right_brace)) {
                if (value.map.count() != 0) _ = try self.stream.eat(.comma);
                const k = try self.stream.eat(.string);
                errdefer self.allocator.free(k.value.?.string);
                _ = try self.stream.eat(.colon);
                const v = try self.parseValue();
                errdefer v.deinit(self.allocator);
                try value.map.put(k.value.?.string, v);
            }
            _ = try self.stream.eat(.right_brace);
            self.decrementDepth(1);
            return value;
        },
        .boolean => return try Value.from(self.allocator, next.value.?.boolean),
        .number => return try Value.from(self.allocator, next.value.?.number),
        .string => return try Value.from(self.allocator, next.value.?.string),
        else => return Error.UnexpectedToken
    }
    unreachable;
}
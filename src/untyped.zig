const std = @import("std");
const Error = @import("error.zig").ParseError;
const Stream = @import("stream.zig");
const Value = @import("value.zig").Value;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;

const Self = @This();

allocator: Allocator,
stream: *Stream,

depth: usize = 0,
max_depth: usize = 512,

// Parses untyped JSON, 
// returning ownership of a Value that the user is responsible for cleaning up.
pub fn parse(allocator: Allocator, reader: std.io.AnyReader) Error!*Value {
    var stream = Stream.from(allocator, reader);
    defer stream.deinit();

    var parser = Self{.allocator = allocator, .stream = &stream};
    return try parser.parseValue();
}

fn incrementDepth(self: *Self, increment: usize) void {
    self.depth += increment;
    if (self.depth > self.max_depth) std.debug.panic("Max supported depth of {any}\n", .{self.max_depth});
}

fn decrementDepth(self: *Self, decrement: usize) void {
    const new_depth = @subWithOverflow(self.depth, decrement);
    std.debug.assert(new_depth[1] != 1); // Overflows shouldn't happen.
    self.depth = new_depth[0];
}

// Parse the next Value.
fn parseValue(self: *Self) Error!*Value {
    const next = try self.stream.advance();
    switch (next.kind) {
        .left_bracket => {
            var value = Value.from(self.allocator, ArrayList(*Value).init(self.allocator));
            self.incrementDepth(1);
            while (!try self.stream.match(.right_bracket)) {
                try value.array.append(try self.parseValue());
            }
            _ = try self.stream.eat(.right_bracket);
            self.decrementDepth(1);
            std.debug.print("{any}\n", .{value});
            return value;
        },
        .left_brace => {
            var value = Value.from(self.allocator, StringHashMap(*Value).init(self.allocator));
            errdefer value.deinit(self.allocator);
            self.incrementDepth(1);
            while (!try self.stream.match(.right_brace)) {
                if (value.object.count() != 0) _ = try self.stream.eat(.comma);
                if ((try self.stream.peek()).kind != .string) return Error.UnexpectedToken;
                const k = try self.parseValue();
                errdefer k.deinit(self.allocator);
                _ = try self.stream.eat(.colon);
                const v = try self.parseValue();
                errdefer v.deinit(self.allocator);
                try value.object.put(k.string, v);
            }
            _ = try self.stream.eat(.right_brace);
            self.decrementDepth(1);
            return value;
        },
        .boolean => return Value.from(self.allocator, next.value.?.boolean),
        .number => return Value.from(self.allocator, next.value.?.number),
        .string => return Value.from(self.allocator, next.value.?.string),
        else => {}
    }
    return Value.from(self.allocator, .nil, true);
}
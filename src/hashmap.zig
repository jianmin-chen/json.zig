// Thin wrapper around StringHashMap unless I can find a better option.

const std = @import("std");
const deserialize = @import("typed.zig");
const serialize = @import("stringify.zig");

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

const Parser = deserialize.Typed;

pub fn HashMap(comptime V: type) type {
    return struct {
        map: StringHashMap(V),

        const Self = @This();

        pub fn fromJSON(parser: *Parser(HashMap(V))) deserialize.Error!Self {
            var self = Self{.map = StringHashMap(V).init(parser.value_allocator.allocator())};

            _ = try parser.stream.eat(.left_brace);
            parser.incrementDepth(1);

            while (!try parser.stream.match(.right_brace)) {
                if (self.map.count() != 0) _ = try parser.stream.eat(.comma);

                // We have ownership of all strings,
                // so types that implement `fromJSON()` must be responsible for deallocating
                // there strings using the passed parser's allocator.
                //
                // Here, we want to transfer ownership of it so we dupe to a different allocator + deallocate.
                const k = try parser.stream.eat(.string);
                const key = k.value.?.string;
                defer parser.allocator.free(key);

                _ = try parser.stream.eat(.colon);

                try self.map.put(
                    try parser.value_allocator.allocator().dupe(u8, key),
                    try parser.typeValue(V)
                );
            }

            parser.decrementDepth(1);
            return self;
        }
    };
}
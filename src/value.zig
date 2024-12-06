const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;

pub const ValueType = enum{string, number, object, array, boolean, nil};

pub const Value = union(ValueType) {
    string: []const u8,
    number: f64,
    object: StringHashMap(*Value),
    array: ArrayList(*Value),
    boolean: bool,
    nil: bool,

    pub fn from(allocator: Allocator, raw: anytype) !*Value {
        const value = try allocator.create(Value);
        if (@TypeOf(raw) == []const u8) {
            value.* = .{.string = raw};
        }
        return value;
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |*string| allocator.free(string.*),
            .object => |*object| {
                var entries = object.iterator();
                while (entries.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.*.deinit(allocator);
                }
            },
            .array => |*array| {
                for (array.items) |value| value.deinit(allocator);
                array.deinit();
            },
            else => {}
        }
        allocator.destroy(self);
    }
};
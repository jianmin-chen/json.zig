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
        } else if (@TypeOf(raw) == f64) {
            value.* = .{.number = raw};
        } else if (@TypeOf(raw) == StringHashMap(*Value)) {
            value.* = .{.object = raw};
        } else if (@TypeOf(raw) == ArrayList(*Value)) {
            value.* = .{.array = raw};
        } else if (@TypeOf(raw) == bool) {
            value.* = .{.boolean = raw};
        } else value.* = .{.nil = true};
        return value;
    }

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |string| {
                allocator.free(string);
            },
            .object => |*object| {
                var entries = object.iterator();
                while (entries.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.*.deinit(allocator);
                }
                object.deinit();
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
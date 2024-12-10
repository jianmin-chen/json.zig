const std = @import("std");
const shared = @import("shared.zig");
const Stream = @import("stream.zig");
const Value = @import("value.zig").Value;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const Error = error{MissingField, UnknownField} || shared.ParseError;
const ParseOptions = shared.ParseOptions;

pub fn Typed(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        arena: ArenaAllocator,
        stream: *Stream,

        value_allocator: ArenaAllocator,
        value: T = undefined,

        depth: usize = 0,
        max_depth: usize,

        strict: bool,

        pub fn parse(
            allocator: Allocator,
            reader: std.io.AnyReader,
            options: ParseOptions
        ) Error!Self {
            var stream = try Stream.from(allocator, reader);
            errdefer stream.cleanup();
            defer stream.deinit();

            var parser = Self{
                .allocator = allocator,
                .arena = ArenaAllocator.init(allocator),
                .stream = &stream,

                .value_allocator = ArenaAllocator.init(allocator),
                
                .max_depth = options.max_depth,
                .strict = options.typed.strict
            };
            defer parser.arena.deinit();
            errdefer parser.deinit();
            parser.value = parser.typeValue(T) catch |err| {
                std.debug.print("{any} {any}\n", .{err, parser.stream.peek()});
                return err;
            };
            return parser;
        }

        pub fn deinit(self: *Self) void {
            self.value_allocator.deinit();
        }

        fn incrementDepth(self: *Self, increment: usize) void {
            self.depth += increment;
            if (self.depth > self.max_depth) std.debug.panic("Max supported depth of {any} exceeded\n", .{self.max_depth});
        }

        fn decrementDepth(self: *Self, decrement: usize) void {
            const new_depth = @subWithOverflow(self.depth, decrement);
            std.debug.assert(new_depth[1] != 1);
            self.depth = new_depth[0];
        }

        // Parses typed JSON.
        // 
        // We do this by making use of Zig's metaprogramming capabilities and
        // recursively going through T.
        pub fn typeValue(self: *Self, comptime TypedValue: type) Error!TypedValue {
            const info = @typeInfo(TypedValue);
            switch (info) {
                .Int, .ComptimeInt => {
                    const token = try self.stream.eat(.number);
                    return @intFromFloat(token.value.?.number);
                },
                .Float, .ComptimeFloat => {
                    const token = try self.stream.eat(.number);
                    return @floatCast(token.value.?.number);
                },
                .Bool => {
                    const token = try self.stream.eat(.boolean);
                    return token.value.?.boolean;
                },
                .Optional => |optional_info| {
                    if (try self.stream.match(.nil)) return null;
                    return try self.typeValue(optional_info.child);
                },
                .Pointer => |ptr_info| {
                    switch (ptr_info.size) {
                        .One => {
                            const allocator = self.value_allocator.allocator();
                            const value = try allocator.create(ptr_info.child);
                            value.* = try self.typeValue(ptr_info.child);
                            return value;
                        },
                        .Slice => {
                            // Parse either array or string.
                            if (try self.stream.match(.left_bracket)) {
                                _ = try self.stream.eat(.left_bracket);
                                self.incrementDepth(1);

                                var array = ArrayList(ptr_info.child).init(self.value_allocator.allocator());
                                errdefer array.deinit();
                                while (!try self.stream.match(.right_bracket)) {
                                    if (array.items.len != 0) _ = try self.stream.eat(.comma);
                                    try array.append(try self.typeValue(ptr_info.child));
                                }

                                _ = try self.stream.eat(.right_bracket);
                                self.decrementDepth(1);
                                return array.toOwnedSlice();
                            } else if (ptr_info.child == u8 and try self.stream.match(.string)) {
                                const token = try self.stream.eat(.string);
                                const string = token.value.?.string;
                                defer self.allocator.free(string);
                                return try self.value_allocator.allocator().dupe(u8, string);
                            } else return Error.UnexpectedToken;
                        },
                        else => @compileError("Unable to parse into type " ++ @typeName(TypedValue))
                    }
                },
                .Struct => |struct_info| {
                    // We need to match up keys to their appropriate types in the struct,
                    // and also throw an error for unknown keys or discard them depending on `self.strict`.
                    _ = try self.stream.eat(.left_brace);
                    self.incrementDepth(1);

                    var partial_object = try self.value_allocator.allocator().create(Partial(TypedValue));
                    partial_object.* = Partial(TypedValue){};

                    var fields: usize = 0;
                    while (!try self.stream.match(.right_brace)) {
                        if (fields != 0) _ = try self.stream.eat(.comma);

                        // Grab key and search for appropriate type.
                        const k = try self.stream.eat(.string);
                        const key = k.value.?.string;
                        defer self.allocator.free(key);

                        _ = try self.stream.eat(.colon);

                        var found: bool = false;
                        inline for (struct_info.fields) |field| {
                            if (std.mem.eql(u8, field.name, key)) {
                                @field(partial_object, field.name) = try self.typeValue(field.type);
                                found = true;
                                break;
                            }
                        }

                        fields += 1;
                        if (!found and self.strict) return Error.UnknownField;
                    }

                    _ = try self.stream.eat(.right_brace);
                    self.decrementDepth(1);

                    // Coerce Partial(TypedValue) into TypedValue,
                    // throwing an error for missing required fields.
                    const value: *TypedValue = @alignCast(@ptrCast(partial_object));
                    return value.*;
                },
                else => @compileError("Unable to parse into type " ++ @typeName(TypedValue))
            }
            unreachable;
        }
    };
}

fn Partial(comptime T: type) type {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |s| {
            comptime var fields: []const std.builtin.Type.StructField = &[_]std.builtin.Type.StructField{};
            inline for (s.fields) |field| {
                if (field.is_comptime)
                    @compileError("Unable to parse comptime field " ++ field.name);
                const default_value: field.type = undefined;
                const aligned_ptr: *align(field.alignment) const anyopaque = @alignCast(@ptrCast(&default_value));
                const optional_field: [1]std.builtin.Type.StructField = [_]std.builtin.Type.StructField{.{
                    .alignment = field.alignment,
                    .default_value = aligned_ptr,
                    .is_comptime = false,
                    .name = field.name,
                    .type = field.type
                }};
                fields = fields ++ optional_field;
            }
            return @Type(.{
                .Struct = .{
                    .backing_integer = s.backing_integer,
                    .decls = &[_]std.builtin.Type.Declaration{},
                    .fields = fields,
                    .is_tuple = s.is_tuple,
                    .layout = s.layout
                }
            });
        },
        else => @compileError("Unable to make Partial(" ++ @typeName(T) ++ ")")
    }
    unreachable;
}

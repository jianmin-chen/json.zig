const std = @import("std");

pub const FormatOptions = struct {
    current_indent: usize = 0,
    indent_size: usize = 2,

    max_length: usize = 80,

    // Enables whether or not we should use a default formatter 
    // if we can't stringify a value.
    strict: bool = false,

    pub fn indent(options: FormatOptions) FormatOptions {
        var shallow_copy = options;
        shallow_copy.current_indent += shallow_copy.indent_size;
        return shallow_copy;
    }
};

pub fn stringify(
    writer: std.io.AnyWriter,
    json: anytype,
    options: FormatOptions
) !void {
    switch (@typeInfo(@TypeOf(json))) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => try writer.print("{d}", .{json}),
        .Bool => try writer.print("{any}", .{json}),
        .Optional => |optional_info| {
            if (json == null) {
                _ = try writer.write("null");
                return;
            }
            const remove_optional: optional_info.child = json.?;
            try stringify(writer, remove_optional, options);
        },
        .Pointer => |ptr_info| {
            switch (ptr_info.size) {
                .One => {
                    std.debug.print("{any}\n", .{json});
                    // try stringify(writer, json.*, options);
                },
                .Slice => {
                    if (ptr_info.child != u8) {
                        _ = try writer.write("[");
                        for (json, 0..) |child, i| {
                            try stringify(writer, child, options);
                            if (i != json.len - 1) _ = try writer.write(",");
                        }
                        _ = try writer.write("]");
                    } else try writer.print("\"{s}\"", .{json});
                },
                else => {
                    if (options.strict) std.debug.panic("Unable to serialize {any}\n", .{json});
                    try writer.print("{any}", .{json});
                }
            }
        },
        .Struct => |struct_info| {
            _ = try writer.write("{");
            inline for (struct_info.fields, 0..) |field, i| {
                try writer.print("\"{s}\":", .{field.name});
                try stringify(writer, @field(json, field.name), options);
                if (i != struct_info.fields.len - 1) _ = try writer.write(",");
            }
            _ = try writer.write("}");
        },
        else => {
            if (options.strict) std.debug.panic("Unable to serialize {any}\n", .{json});
            try writer.print("{any}", .{json});
        }
    }
}

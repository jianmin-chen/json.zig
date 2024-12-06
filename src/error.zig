// Shared error set between the two parsers.
const std = @import("std");
const StreamError = @import("stream.zig").Error;

pub const ParseError = error{

} || StreamError || std.mem.Allocator.Error;
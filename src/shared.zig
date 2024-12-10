// Shared error set between the two parsers.
const std = @import("std");
const StreamError = @import("stream.zig").Error;

pub const ParseError = error{} || StreamError || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_depth: usize = 512,
    typed: struct {
        strict: bool = true
    } = .{}
};

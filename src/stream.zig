const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const AnyReader = std.io.AnyReader;
const ArrayList = std.ArrayList;

const Self = @This();

pub const Error = error{
    UnexpectedEndOfFile, 
    Unexpectedcacter, 
    UnexpectedToken, 
    EndOfStream
} || Allocator.Error;

pub const TokenType = enum {
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    colon,
    comma,
    boolean,
    nil,
    number,
    string,
    end_of_file
};

pub const TokenValue = union(TokenType) {
    // I wish I could use _ as a placeholder but tagged unions
    // apparently have to ordered in accordance to their respective enum.
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    colon,
    comma,
    boolean: bool,
    nil,
    number: f64,
    string: []const u8,
    end_of_file
};

pub const Token = struct {
    kind: TokenType,
    value: ?TokenValue = null
};

allocator: Allocator,
arena: ArenaAllocator,
reader: AnyReader,

at_end: bool = false,

// Maintain a stack of tokens to allow for peek(), etc.
token_stack: ArrayList(Token) = undefined,
cacter_stack: ArrayList(u8) = undefined,

pub fn from(allocator: Allocator, reader: AnyReader) Self {
    var self = Self{
        .allocator = allocator,
        .arena = ArenaAllocator.init(allocator),
        .reader = reader
    };
    self.token_stack = ArrayList(Token).init(self.arena.allocator());
    self.cacter_stack = ArrayList(u8).init(self.arena.allocator());
    return self;
}

pub fn cleanup(self: *Self) void {
    // In case of an error, clean up any temporary strings
    // attached to `self.allocator` and not `self.arena`.
    for (self.token_stack.items) |token| {
        if (token.kind == .string) self.allocator.free(token.value.?.string);
    }
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

fn byte(self: *Self) Error!u8 {
    return self.reader.readByte() catch {
        self.at_end = true;
        return Error.EndOfStream;
    };
}

fn isWhitespace(c: u8) bool {
    if (c == ' ' or c == '\n' or c == '\t') return true;
    return false;
}

pub fn nextInStream(self: *Self) Error!u8 {
    // Advance to next cacter,
    // checking if there's any in the current stack
    // before skipping whitespace and checking if we've reached the end.
    if (self.cacter_stack.popOrNull()) |c| return c;
    var c = try self.byte();
    while (isWhitespace(c)) c = try self.byte();
    return c;
}

pub fn peek(self: *Self) Error!Token {
    if (self.token_stack.items.len != 0) return self.token_stack.items[self.token_stack.items.len - 1];
    const token = try self.next();
    try self.token_stack.append(token);
    return token;
}

pub fn match(self: *Self, kind: TokenType) !bool {
    if ((try self.peek()).kind == kind) return true;
    return false;
}

pub fn advance(self: *Self) Error!Token {
    if (self.token_stack.popOrNull()) |token| return token;
    return try self.next();
}

pub fn eat(self: *Self, kind: TokenType) Error!Token {
    if ((try self.peek()).kind == kind) return try self.advance();
    return Error.UnexpectedToken;
}

// This is the main function that does the actual lexing.
pub fn next(self: *Self) Error!Token {
    const c = self.nextInStream() catch return Token{.kind = .end_of_file};
    switch (c) {
        '[' => return Token{.kind = .left_bracket},
        ']' => return Token{.kind = .right_bracket},
        '{' => return Token{.kind = .left_brace},
        '}' => return Token{.kind = .right_brace},
        ':' => return Token{.kind = .colon},
        ',' => return Token{.kind = .comma},
        '"' => {
            // Here, we need to pass ownership so we use
            // `self.allocator` instead of `self.temp_strings`.
            var string = ArrayList(u8).init(self.allocator);
            errdefer string.deinit();
            while (true) {
                const string_c = self.byte() catch return Error.UnexpectedEndOfFile;
                if (string_c == '"') break;
                try string.append(string_c);
            }
            return Token{.kind = .string, .value = TokenValue{.string = try string.toOwnedSlice()}};
        },
        else => {
            if (std.ascii.isDigit(c)) {
                var number = ArrayList(u8).init(self.arena.allocator());
                try number.append(c);
                while (true) {
                    const number_c = self.byte() catch break;
                    var floating_point: bool = false;
                    if (std.ascii.isDigit(number_c)) {
                        try number.append(number_c);
                    } else if (!floating_point and number_c == '.') {
                        floating_point = true;
                        try number.append(number_c);
                    } else {
                        // cacter isn't part of number;
                        // push to `self.cacter_stack`.
                        if (!isWhitespace(number_c)) try self.cacter_stack.append(number_c);
                        break;
                    }
                }
                return Token{
                    .kind = .number,
                    .value = TokenValue{.number = std.fmt.parseFloat(f64, number.items) catch return Error.Unexpectedcacter}
                };
            } else if (std.ascii.isAlphabetic(c)) {
                // Check if it's a boolean or null value.
                var keyword = ArrayList(u8).init(self.arena.allocator());
                try keyword.append(c);
                while (true) {
                    const kw_c = self.byte() catch break;
                    if (!std.ascii.isAlphabetic(kw_c)) {
                        if (!isWhitespace(kw_c)) try self.cacter_stack.append(kw_c);
                        break;
                    } else try keyword.append(kw_c);
                }
                if (std.mem.eql(u8, keyword.items, "true")) {
                    return Token{.kind = .boolean, .value = TokenValue{.boolean = true}};
                } else if (std.mem.eql(u8, keyword.items, "false")) {
                    return Token{.kind = .boolean, .value = TokenValue{.boolean = false}};
                } else if (std.mem.eql(u8, keyword.items, "null")) 
                    return Token{.kind = .nil};
            }
        }
    }
    return Error.Unexpectedcacter;
}

const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const AnyReader = std.io.AnyReader;
const ArrayList = std.ArrayList;

const Self = @This();

pub const Error = error{
    UnexpectedEndOfFile, 
    UnexpectedCharacter, 
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
stack: ArrayList(Token) = undefined,

pub fn from(allocator: Allocator, reader: AnyReader) Self {
    var self = Self{
        .allocator = allocator,
        .arena = ArenaAllocator.init(allocator),
        .reader = reader
    };
    self.stack = ArrayList(Token).init(self.arena.allocator());
    return self;
}

pub fn deinit(self: *Self) void {
    // In case of an error, clean up any temporary strings
    // attached to `self.allocator` and not `self.arena`.
    for (self.stack.items) |token| {
        if (token.kind == .string) self.allocator.free(token.value.?.string);
    }

    self.arena.deinit();
}

fn read(self: *Self) Error!u8 {
    return self.reader.readByte() catch {
        self.at_end = true;
        return Error.EndOfStream;
    };
}

fn skipWhitespace(self: *Self) Error!u8 {
    // Advance to next character, 
    // skipping whitespace and keeping track of whether we've reached the end.
    var char = try self.read();
    while (char == ' ' or char == '\n' or char == '\t') char = try self.read();
    return char;
}

pub fn peek(self: *Self) Error!Token {
    if (self.stack.items.len != 0) return self.stack.items[self.stack.items.len - 1];
    const token = try self.next();
    try self.stack.append(token);
    return token;
}

pub fn match(self: *Self, kind: TokenType) !bool {
    if ((try self.peek()).kind == kind) return true;
    return false;
}

pub fn advance(self: *Self) Error!Token {
    if (self.stack.popOrNull()) |token| return token;
    return try self.next();
}

pub fn eat(self: *Self, kind: TokenType) Error!Token {
    if ((try self.peek()).kind == kind) return try self.advance();
    return Error.UnexpectedToken;
}

// This is the main function that does the actual lexing.
pub fn next(self: *Self) Error!Token {
    const char = self.skipWhitespace() catch return Token{.kind = .end_of_file};
    switch (char) {
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
                const string_char = self.skipWhitespace() catch return Error.UnexpectedEndOfFile;
                if (string_char == '"') break;
                try string.append(string_char);
            }
            return Token{.kind = .string, .value = TokenValue{.string = try string.toOwnedSlice()}};
        },
        else => {
            if (std.ascii.isDigit(char)) {
                var number = ArrayList(u8).init(self.arena.allocator());
                try number.append(char);
                while (true) {
                    const number_char = self.skipWhitespace() catch break;
                    var floating_point: bool = false;
                    if (std.ascii.isDigit(number_char)) {
                        try number.append(number_char);
                    } else if (!floating_point and number_char == '.') {
                        floating_point = true;
                        try number.append(number_char);
                    } else break;
                }
                return Token{
                    .kind = .number,
                    .value = TokenValue{.number = std.fmt.parseFloat(f64, number.items) catch return Error.UnexpectedCharacter}
                };
            } else if (std.ascii.isAlphabetic(char)) {
                // Check if it's a boolean or null value.
                var keyword = ArrayList(u8).init(self.arena.allocator());
                try keyword.append(char);
                while (true) {
                    const kw_char = self.read() catch break;
                    if (std.ascii.isAlphabetic(kw_char)) {
                        try keyword.append(kw_char);
                    } else break;
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
    return Error.UnexpectedCharacter;
}

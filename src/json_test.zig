const std = @import("std");
const json = @import("json");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Timer = std.time.Timer;

test "All tests in test_parsing pass/fail as dictated" {
    var test_parsing = try std.fs.cwd().openDir("tests/test_parsing", .{});
    defer test_parsing.close();

    const Option = enum{pass, reject};

    var it = test_parsing.iterate();
    while (try it.next()) |entry| {
        const option: Option = if (std.ascii.startsWithIgnoreCase(entry.name, "n")) .reject else .pass;

        const file = try test_parsing.openFile(entry.name, .{});
        defer file.close();

        var reader = file.reader();

        std.debug.print("{s} should {s}\n", .{entry.name, @tagName(option)});

        var parsed = json.parse(std.testing.allocator, reader.any(), .{}) catch {
            try std.testing.expect(option == .reject);
            continue;
        };
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expect(option == .pass);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("tests/test_parsing/i_string_incomplete_surrogates_escape_valid.json", .{});
    defer file.close();

    var reader = file.reader();

    var parsed = try json.parse(allocator, reader.any(), .{});
    defer parsed.deinit(allocator);

    std.debug.print("{s}", .{parsed.array.items[0].string});

    // const file = try std.fs.cwd().openFile("tests/data.json", .{});
    // defer file.close();

    // var reader = file.reader();

    // // Parsing untyped JSON might look somethings like this.
    // var parsed = try json.parse(allocator, reader.any(), .{});
    // // Calling `Value.deinit` cleans up the Value that gets returned.
    // // Parsing is done with a ArenaAllocator, which automatically gets
    // // cleaned up when the parsing is done.
    // defer parsed.deinit(allocator);
    // for (parsed.array.items) |pokemon| {
    //     const images = pokemon.map.get("images").?;
    //     std.debug.print("{s}: {s}\n", .{pokemon.map.get("name").?.string, images.map.get("small").?.string});
    // }

    // // Parsing typed JSON might look something like this.
    // var timer = try Timer.start();
    // var typed: json.Typed([]Pokemon) = try json.Typed([]Pokemon).parse(allocator, reader.any(), .{});
    // const time = timer.lap();
    // // Allocation of the original value is left up to the user to handle;
    // // however, any allocations made by the parser are handled by calling `json.TypedValue.deinit`.
    // defer typed.deinit();
    // for (typed.value) |pokemon| {
    //     std.debug.print("{s}: {s}\n", .{pokemon.name, pokemon.images.small});
    //     if (pokemon.flavorText.len != 0) std.debug.print("   | {s}\n", .{pokemon.flavorText});
    //     for (pokemon.attacks) |attack| {
    //         std.debug.print("   {s}\n", .{attack.name});
    //     }
    // }
    // std.debug.print("Total number of cards in set: {any}\n", .{typed.value.len});
    // std.debug.print("Approximate time: {any}\n", .{time}); // <- Approx. 1.35 seconds to parse 1MB.

    // Stringifying JSON might look something like this.
    const write_file = try std.fs.cwd().createFile("test.json", .{});
    defer write_file.close();

    var characters = json.HashMap(Character).init(allocator);
    defer {
        var entries = characters.map.valueIterator();
        while (entries.next()) |entry| {
            allocator.free(entry.grapheme);
        }
        characters.deinit();
    }
    try insert(allocator, &characters.map, 0x005C);

    try json.stringify(write_file.writer().any(), characters, .{});
}

fn insert(allocator: Allocator, characters: *StringHashMap(Character), codepoint: u21) !void {
    const buf = try allocator.alloc(u8, try std.unicode.utf8CodepointSequenceLength(codepoint));
    _ = try std.unicode.utf8Encode(codepoint, buf);
    try characters.put(buf, Character{.grapheme = buf, .advance_x = 2});
}

const Ability = struct {
    name: []const u8,
    text: []const u8,
    @"type": []const u8
};

const Attack = struct {
    name: []const u8,
    cost: [][]const u8,
    convertedEnergyCost: usize,
    damage: []const u8,
    text: []const u8
};

const Effect = struct {
    @"type": []const u8,
    value: []const u8
};

const Pokemon = struct {
    id: []const u8,
    name: []const u8,
    supertype: []const u8,
    subtypes: [][]const u8,
    level: []const u8,
    hp: []const u8,
    types: [][]const u8,
    evolvesFrom: []const u8,
    evolvesTo: [][]const u8,
    abilities: []Ability,
    attacks: []Attack,
    weaknesses: []Effect,
    resistances: []Effect,
    retreatCost: [][]const u8,
    convertedRetreatCost: usize,
    number: []const u8,
    artist: []const u8,
    rarity: []const u8,
    flavorText: []const u8,
    nationalPokedexNumbers: []usize,
    legalities: struct {
        unlimited: ?[]const u8 = null,
        standard: ?[]const u8 = null,
        expanded: ?[]const u8 = null
    },
    images: struct {
        small: []const u8,
        large: []const u8
    },
    rules: [][]const u8
};

const Character = struct {
    grapheme: []u8,
    top: f32 = 0,
    left: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    bearing_x: f32 = 0,
    bearing_y: f32 = 0,
    advance_x: c_long = 0,
    advance_y: c_long = 0
};
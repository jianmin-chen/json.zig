const std = @import("std");
const json = @import("json");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Ability = struct {
    name: []const u8,
    text: []const u8,
    type: []const u8
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
    attacks: []struct {
        name: []const u8,
        cost: [][]const u8,
        convertedEnergyCost: usize,
        damage: []const u8,
        text: []const u8
    },
    weaknesses: []struct {
        type: []const u8,
        value: []const u8
    },
    resistances: []struct {
        type: []const u8,
        value: []const u8
    },
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
    top: f32 = 0,
    left: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    bearing_x: f32 = 0,
    bearing_y: f32 = 0,
    advance_x: c_long = 0,
    advance_y: c_long = 0 
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.json", .{});
    defer file.close();

    var reader = file.reader();

    // // Parsing untyped JSON might look something like this.
    // var parsed = try json.parse(allocator, reader.any(), .{});
    // // Calling deinit() cleans up the Value that gets returned.
    // // Parsing is done with a ArenaAllocator, which automatically gets
    // // cleaned up when the parsing is done.
    // defer parsed.deinit(allocator);
    // var keys = parsed.array.items[0].object.keyIterator();
    // while (keys.next()) |key| {
    //     std.debug.print("{s}\n", .{key.*});
    // }
    // for (parsed.array.items) |pokemon| {
    //     std.debug.print("{s} has an HP of {s}\n", .{pokemon.object.get("name").?.string, pokemon.object.get("hp").?.string});
    //     const images = pokemon.object.get("images").?;
    //     std.debug.print("{s}\n", .{images.object.get("small").?.string});
    // }

    // Parsing typed JSON might look something like this.
    const parsed = try json.Typed([]Pokemon).parse(allocator, reader.any(), .{});
    // Allocation is left up to the user to handle depending on the type.
    defer allocator.free(parsed);
    const pokemon = parsed[0];
    std.debug.print("{s}\n", .{pokemon.images.large});
    // for (parsed.value.items) |pokemon| {
    //     std.debug.print("{any}\n", .{pokemon});
    // }

    // Stringifying JSON might look something like this.
    // const pokemon = Pokemon{
    //     .id = 0,
    //     .name = "Alakazam",
    //     .supertype = "Pokemon",
    //     .subtypes = [_][]const u8{"Stage 2"},
    //     .level = "42",
    //     .hp = "80",
    //     .types = [_][]const u8{"Psychic"},
    //     .evolvesFrom = "Kadabra",
    //     .abilities = [_]
    // };
    // const write_file = try std.fs.cwd().createFile("test.json", .{});
    // defer write_file.close();
    // try json.stringify(allocator, file.writer().any(), character, .{});
}
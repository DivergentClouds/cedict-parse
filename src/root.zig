const std = @import("std");

pub const Entry = struct {
    traditional: []u8,
    simplified: []u8,

    pinyin: []u8,

    definitions: [][]u8,

    /// The passed allocator must be the same one used for creating the `Entry`
    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.traditional);
        allocator.free(self.simplified);
        allocator.free(self.pinyin);

        for (self.definitions) |definition| {
            allocator.free(definition);
        }
        allocator.free(self.definitions);
    }
};

pub fn parseLine(line: []const u8, allocator: std.mem.Allocator) !?Entry {
    if (line[0] == '#')
        return null;

    var line_tokens = std.mem.tokenizeScalar(u8, line, ' ');

    var result = Entry{
        .traditional = undefined,
        .simplified = undefined,
        .pinyin = undefined,
        .definitions = undefined,
    };

    result.traditional = try allocator.dupe(u8, line_tokens.next() orelse
        return error.InvalidLine);
    errdefer allocator.free(result.traditional);

    result.simplified = try allocator.dupe(u8, line_tokens.next() orelse
        return error.InvalidLine);
    errdefer allocator.free(result.simplified);

    const pinyin = line_tokens.next() orelse
        return error.InvalidLine;

    result.pinyin = try allocator.dupe(u8, pinyin[1 .. pinyin.len - 1]);
    errdefer allocator.free(result.pinyin);

    const definitions = line_tokens.rest();

    var definitions_list = std.ArrayList([]u8).init(allocator);
    defer definitions_list.deinit();
    errdefer for (definitions_list.items) |item| {
        allocator.free(item);
    };

    var definition_tokens = std.mem.tokenizeScalar(u8, definitions, '/');
    while (definition_tokens.next()) |definition| {
        try definitions_list.append(try allocator.dupe(u8, definition));
    }

    result.definitions = try definitions_list.toOwnedSlice();
    return result;
}

test parseLine {
    const allocator = std.testing.allocator;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    const writer = list.writer();

    const line = "麵 面 [mian4] /flour/noodles/(of food) soft (not crunchy)/(slang) (of a person) ineffectual/spineless/";

    var entry = try parseLine(line, allocator) orelse
        return error.Comment;
    defer entry.deinit(allocator);

    try writer.print(
        \\traditional: {s}
        \\simplified: {s}
        \\pinyin: {s}
        \\
        \\definitions:
        \\
    ,
        .{
            entry.traditional,
            entry.simplified,
            entry.pinyin,
        },
    );
    for (entry.definitions) |definition| {
        try writer.print(
            \\    - {s}
            \\
        , .{definition});
    }

    try std.testing.expect(std.mem.eql(u8, list.items,
        \\traditional: 麵
        \\simplified: 面
        \\pinyin: mian4
        \\
        \\definitions:
        \\    - flour
        \\    - noodles
        \\    - (of food) soft (not crunchy)
        \\    - (slang) (of a person) ineffectual
        \\    - spineless
        \\
    ));
}

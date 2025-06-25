const std = @import("std");

/// A parsed dictionary entry.
pub const Entry = struct {
    traditional: []u8,
    simplified: []u8,

    pinyin: []u8,

    definitions: [][]const u8,

    /// The passed allocator must be the same one used for creating the `Entry`.
    pub fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        allocator.free(self.traditional);
        allocator.free(self.simplified);
        allocator.free(self.pinyin);

        for (self.definitions) |definition| {
            allocator.free(definition);
        }
        allocator.free(self.definitions);
    }

    /// Convert all pinyin in `self` to use diacritics for tones rather than
    /// numbers.
    pub fn toDiacriticForm(self: *Entry, allocator: std.mem.Allocator) !void {
        const new_pinyin = try toDiacriticSyllables(self.pinyin, allocator);
        allocator.free(self.pinyin);
        self.pinyin = new_pinyin;

        for (self.definitions) |*definition| {
            var definition_list = std.ArrayList(u8).init(allocator);
            defer definition_list.deinit();

            var pinyin_position = std.mem.indexOfScalar(u8, definition.*, '[');
            var partial_definition = definition.*;

            while (pinyin_position) |position| : ({
                pinyin_position = std.mem.indexOfScalarPos(
                    u8,
                    partial_definition,
                    position + 1,
                    '[',
                );
            }) {
                try definition_list.appendSlice(partial_definition[0..position]);
                try definition_list.append('[');

                var pinyin_tokens = std.mem.tokenizeScalar(
                    u8,
                    partial_definition[position..],
                    ']',
                );

                const token = pinyin_tokens.next() orelse
                    std.debug.panic("Unfinished pinyin in definition: {s}\n", .{definition.*});

                const with_diacritics = try toDiacriticSyllables(
                    token[1..],
                    allocator,
                );
                defer allocator.free(with_diacritics);
                try definition_list.appendSlice(with_diacritics);

                try definition_list.append(']');

                partial_definition = pinyin_tokens.rest();
            }

            try definition_list.appendSlice(partial_definition);

            allocator.free(definition.*);
            definition.* = try definition_list.toOwnedSlice();
        }
    }
};

/// Returns null if given a comment. Attempts to parse `line` otherwise.
/// Caller owns the result.
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

    line_tokens = std.mem.tokenizeScalar(u8, line_tokens.rest(), ']');

    const pinyin = line_tokens.next() orelse
        return error.InvalidLine;

    // skip '['
    result.pinyin = try allocator.dupe(u8, pinyin[1..]);
    errdefer allocator.free(result.pinyin);

    // skip trailing space
    const definitions = line_tokens.rest()[1..];

    var definitions_list = std.ArrayList([]const u8).init(allocator);
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

/// Turn a string containing multiple space-seperated pinyin syllables written
/// with numbers to written with diacritics. Caller owns the returned value.
pub fn toDiacriticSyllables(pinyin: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var syllables = std.mem.tokenizeScalar(u8, pinyin, ' ');

    var pinyin_list = std.ArrayList(u8).init(allocator);

    while (syllables.next()) |syllable| {
        const with_diacritics = try toDiacriticSingle(syllable, allocator);
        defer allocator.free(with_diacritics);

        try pinyin_list.appendSlice(with_diacritics);
        try pinyin_list.append(' ');
    }

    _ = pinyin_list.pop(); // get rid of extra space

    return try pinyin_list.toOwnedSlice();
}

/// Turn a pinyin syllable written with numbers to be written with diacritics.
/// Caller owns both `pinyin` and returned value.
pub fn toDiacriticSingle(pinyin: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var pinyin_list = std.ArrayList(u8).init(allocator);
    defer pinyin_list.deinit();

    const vowel_count = countVowels(pinyin);
    var vowels_parsed: usize = 0;
    var mark_placed: bool = false;

    const tone = getTone(pinyin);

    var i: usize = 0;

    while (i < pinyin.len) : (i += 1) {
        const char = pinyin[i];

        if (isDigit(char))
            continue;

        if (isConsonant(char) or mark_placed) {
            try pinyin_list.append(char);
            continue;
        }

        if (vowel_count == 1) {
            // can only be "u:"
            if (i < pinyin.len - 1 and pinyin[i + 1] == ':') {
                try pinyin_list.appendSlice(
                    toneToDiacritic(tone, "ǖǘǚǜü", &.{ 2, 2, 2, 2, 2 }),
                );
            } else {
                try pinyin_list.appendSlice(
                    toDiacriticVowel(char, tone),
                );
            }
            // not nessecary due to this being the only vowel
            // mark_placed = true;
        } else {
            if (!mark_placed) {
                if (vowels_parsed == 1) {
                    try pinyin_list.appendSlice(
                        toDiacriticVowel(char, tone),
                    );
                    mark_placed = true;
                } else {
                    switch (char) {
                        'a', 'e', 'A', 'E' => {
                            try pinyin_list.appendSlice(
                                toDiacriticVowel(char, tone),
                            );
                            mark_placed = true;
                        },
                        'o', 'O' => {
                            try pinyin_list.appendSlice(
                                toDiacriticVowel(char, tone),
                            );
                            mark_placed = true;
                        },
                        'u' => {
                            if (i < pinyin.len - 1 and pinyin[i + 1] == ':') {
                                try pinyin_list.appendSlice("ü");
                                i += 1;
                            } else {
                                try pinyin_list.append(char);
                            }
                        },
                        else => {
                            try pinyin_list.append(char);
                        },
                    }
                }
            } else {
                try pinyin_list.append(char);
            }
        }
        vowels_parsed += 1;
    }

    return try pinyin_list.toOwnedSlice();
}

fn toDiacriticVowel(vowel: u8, tone: u3) []const u8 {
    const tone_char_lengths = [_]u3{ 2, 2, 2, 2, 1 };
    return switch (vowel) {
        'a' => toneToDiacritic(tone, "āáǎàa", &tone_char_lengths),
        'e' => toneToDiacritic(tone, "ēéěèe", &tone_char_lengths),
        'i' => toneToDiacritic(tone, "īíǐìi", &tone_char_lengths),
        'o' => toneToDiacritic(tone, "ōóǒòo", &tone_char_lengths),
        'u' => toneToDiacritic(tone, "ūúǔùu", &tone_char_lengths),
        'A' => toneToDiacritic(tone, "ĀÁǍÀA", &tone_char_lengths),
        'E' => toneToDiacritic(tone, "ĒÉĚÈE", &tone_char_lengths),
        'I' => toneToDiacritic(tone, "ĪÍǏÌI", &tone_char_lengths),
        'O' => toneToDiacritic(tone, "ŌÓǑÒO", &tone_char_lengths),
        'U' => toneToDiacritic(tone, "ŪÚǓÙU", &tone_char_lengths),
        else => std.debug.panic("Invalid Character '{c}'\n", .{vowel}),
    };
}

fn toneToDiacritic(tone: u3, canidates: []const u8, bytes_per_canidate: *const [5]u3) []const u8 {
    var offset: usize = 0;
    // don't include tone canidate in offset
    for (0..tone - 1) |i| {
        offset += bytes_per_canidate[i];
    }

    // tone is 1 indexed, but array access is 0 indexed
    return canidates[offset .. offset + bytes_per_canidate[tone - 1]];
}

fn isDigit(char: u8) bool {
    return switch (char) {
        '0'...'9' => true,
        else => false,
    };
}

fn isVowel(char: u8) bool {
    const vowels = "aeiouAEIOU";

    return for (vowels) |vowel| {
        if (char == vowel)
            break true;
    } else false;
}

fn countVowels(string: []const u8) usize {
    var result: usize = 0;
    for (string) |char| {
        if (isVowel(char))
            result += 1;
    }
    return result;
}

/// Turns a digit '1' through '5' into an integer 1 through 5.
/// Asserts that digit is in range.
fn getTone(string: []const u8) u3 {
    const tone_digit = string[string.len - 1];

    std.debug.assert(tone_digit >= '1' and tone_digit <= '5');

    return @intCast(tone_digit - '0');
}

fn isConsonant(char: u8) bool {
    return !isVowel(char) and std.ascii.isAlphabetic(char);
}

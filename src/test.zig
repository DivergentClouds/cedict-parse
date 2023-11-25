const std = @import("std");
const testing = std.testing;
const cedict = @import("cedict-parse");

test "toDiacriticSyllable" {
    const allocator = testing.allocator;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    const writer = list.writer();

    const syllables: []const []const u8 = &.{
        "ma1",
        "ma2",
        "ma3",
        "ma4",
        "ma5",
        "huan1",
        "huan2",
        "huan3",
        "huan4",
        "huan5",
        "zhuai1",
        "zhuai2",
        "zhuai3",
        "zhuai4",
        "zhuai5",
        "zui1",
        "zui2",
        "zui3",
        "zui4",
        "zui5",
        "jiu1",
        "jiu2",
        "jiu3",
        "jiu4",
        "jiu5",
        "Ou1",
        "Ou2",
        "Ou3",
        "Ou4",
        "Ou5",
        "lu:e1",
        "lu:e2",
        "lu:e3",
        "lu:e4",
        "lu:e5",
        "xx5",
    };

    for (syllables) |syllable| {
        const with_diacritics = try cedict.toDiacriticSingle(syllable, allocator);
        defer allocator.free(with_diacritics);
        try writer.print("{s} -> {s}\n", .{
            syllable,
            with_diacritics,
        });
    }

    try testing.expectEqualSlices(u8, list.items,
        \\ma1 -> mā
        \\ma2 -> má
        \\ma3 -> mǎ
        \\ma4 -> mà
        \\ma5 -> ma
        \\huan1 -> huān
        \\huan2 -> huán
        \\huan3 -> huǎn
        \\huan4 -> huàn
        \\huan5 -> huan
        \\zhuai1 -> zhuāi
        \\zhuai2 -> zhuái
        \\zhuai3 -> zhuǎi
        \\zhuai4 -> zhuài
        \\zhuai5 -> zhuai
        \\zui1 -> zuī
        \\zui2 -> zuí
        \\zui3 -> zuǐ
        \\zui4 -> zuì
        \\zui5 -> zui
        \\jiu1 -> jiū
        \\jiu2 -> jiú
        \\jiu3 -> jiǔ
        \\jiu4 -> jiù
        \\jiu5 -> jiu
        \\Ou1 -> Ōu
        \\Ou2 -> Óu
        \\Ou3 -> Ǒu
        \\Ou4 -> Òu
        \\Ou5 -> Ou
        \\lu:e1 -> lüē
        \\lu:e2 -> lüé
        \\lu:e3 -> lüě
        \\lu:e4 -> lüè
        \\lu:e5 -> lüe
        \\xx5 -> xx
        \\
    );
}

test "parseLine" {
    const allocator = testing.allocator;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    const writer = list.writer();

    const line = "麵 面 [mian4] /flour/noodles/(of food) soft (not crunchy)/(slang) (of a person) ineffectual/spineless/";

    var entry = try cedict.parseLine(line, allocator) orelse
        return error.UnexpectedComment;
    defer entry.deinit(allocator);

    try writer.print(
        \\traditional: {s}
        \\simplified: {s}
        \\pinyin: {s}
        \\
        \\definitions:
        \\
    , .{
        entry.traditional,
        entry.simplified,
        entry.pinyin,
    });
    for (entry.definitions) |definition| {
        try writer.print(
            \\    - {s}
            \\
        , .{definition});
    }

    try testing.expectEqualSlices(u8, list.items,
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
    );
}

test "Entry.toDiacriticForm" {
    const allocator = testing.allocator;

    const line = "主意 主意 [zhu3 yi5] /plan/idea/decision/CL:個|个[ge4]/Beijing pr. [zhu2 yi5]/";

    var entry = try cedict.parseLine(line, allocator) orelse
        return error.UnexpectedComment;
    defer entry.deinit(allocator);

    try entry.toDiacriticForm(allocator);

    try testing.expectEqualSlices(u8, entry.pinyin, "zhǔ yi");

    try testing.expectEqualSlices(u8, entry.definitions[3], "CL:個|个[gè]");
    try testing.expectEqualSlices(u8, entry.definitions[4], "Beijing pr. [zhú yi]");
}

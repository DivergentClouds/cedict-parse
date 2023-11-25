# CEDICT-Parse

A small zig library for parsing CEDICT data.

## Barebones example

```zig
const std = @import("std");
const cedict = @import("cedict-parse");

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer gpa.deinit();

  const allocator = gpa.allocator();

  const definition =
    "皮實 皮实 [pi2 shi5] /(of things) durable/(of people) sturdy; tough/";

  var parsed = try cedict.parseLine(defintion, allocator);
  defer parsed.deinit(allocator);

  const stdout = std.io.getStdOut();
  stdout.writer.print(
    \\simplified: {s},
    \\pinyin: {s}
    \\
    ,.{
      parsed.simplified,
      parsed.pinyin,
    }
  )
}
```

## See also
- https://en.wikipedia.org/wiki/CEDICT
- https://cc-cedict.org/wiki/format:syntax

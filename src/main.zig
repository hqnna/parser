const std = @import("std");
const Tokenizer = @import("json/tokenizer.zig");
const Parser = @import("json/parser.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;

    const data = try std.Io.Dir.cwd().readFileAlloc(init.io, "test/data.json", allocator, .unlimited);
    defer allocator.free(data);

    var tokenizer = Tokenizer.init(data);
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    var v = try parser.parseValue();
    defer v.deinit(allocator);
}

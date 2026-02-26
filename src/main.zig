const std = @import("std");
const Tokenizer = @import("vm/tokenizer.zig");
const Parser = @import("vm/parser.zig");
const ASTGen = @import("vm/astgen.zig");

fn dump(node: *const ASTGen.Node, indent: usize) void {
    for (0..indent) |_| std.debug.print("  ", .{});

    switch (node.*) {
        .value => |v| std.debug.print("value({d})\n", .{v}),
        .operation => |op| {
            std.debug.print("op({s})\n", .{@tagName(op.op)});
            dump(op.lhs, indent + 1);
            dump(op.rhs, indent + 1);
        },
    }
}

pub fn main() !void {
    const data = "13 + (12 + (64 * 2))";
    const allocator = std.heap.smp_allocator;
    var tokenizer = Tokenizer.init(data);
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    const values = try parser.parse();
    defer allocator.free(values);

    var astgen = ASTGen.init(allocator, values);
    const ast = try astgen.expr();
    defer ast.deinit(allocator);

    dump(ast, 0);
}

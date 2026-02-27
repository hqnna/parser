const std = @import("std");
const Tokenizer = @import("vm/tokenizer.zig");
const Parser = @import("vm/parser.zig");
const ASTGen = @import("vm/astgen.zig");
const VM = @import("vm/vm.zig");

pub fn main(init: std.process.Init) !void {
    var argv = init.minimal.args.iterate();
    _ = argv.skip();

    var tokenizer = Tokenizer.init(argv.next().?);
    const allocator = std.heap.smp_allocator;
    var parser = try Parser.init(allocator, &tokenizer);
    defer parser.deinit();

    const values = try parser.parse();
    defer allocator.free(values);

    var astgen = ASTGen.init(allocator, values);
    const ast = try astgen.expr();
    defer ast.deinit(allocator);

    const vm = VM.init(ast);
    const result = try vm.exec();

    switch (result.number) {
        .float => |v| std.log.debug("{d}", .{v}),
        .int => |v| std.log.debug("{d}", .{v}),
    }
}

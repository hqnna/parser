const Parser = @This();
const std = @import("std");
const Tokenizer = @import("tokenizer.zig");

pub const Value = union(enum(u8)) {
    pub const Operator = enum(u8) { add, sub, mul, div };
    pub const Scope = enum(u8) { open, close };

    operator: Operator,
    scope: Scope,
    number: usize,
};

cursor: usize,
buffer: []const u8,
tokens: []const Tokenizer.Token,
allocator: std.mem.Allocator,

pub const Error =
    std.mem.Allocator.Error ||
    std.fmt.ParseIntError ||
    error{ParseError};

pub fn init(allocator: std.mem.Allocator, tokenizer: *Tokenizer) Error!Parser {
    var tokens = try std.ArrayList(Tokenizer.Token).initCapacity(allocator, 5);
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |token| try tokens.append(allocator, token);

    return .{
        .cursor = 0,
        .buffer = tokenizer.buffer,
        .tokens = try tokens.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: Parser) void {
    self.allocator.free(self.tokens);
}

pub fn parse(self: *Parser) Error![]const Value {
    var values = try std.ArrayList(Value).initCapacity(self.allocator, 5);
    defer values.deinit(self.allocator);

    while (self.cursor < self.tokens.len) : (self.cursor += 1) {
        if (self.tokens[self.cursor].kind == .space) continue;
        try values.append(self.allocator, self.parseNumber() catch
            self.parseOperator() catch
            try self.parseScope());
    }

    return values.toOwnedSlice(self.allocator);
}

fn parseNumber(self: *Parser) Error!Value {
    const token = self.tokens[self.cursor];
    if (token.kind != .number) return Error.ParseError;

    const value = try std.fmt.parseInt(usize, self.buffer[token.start.? .. token.end.? + 1], 10);
    return .{ .number = value };
}

fn parseOperator(self: *Parser) Error!Value {
    const token = self.tokens[self.cursor];
    if (token.kind != .operator) return Error.ParseError;

    return Value{
        .operator = switch (self.buffer[token.start.?]) {
            '+' => .add,
            '-' => .sub,
            '*' => .mul,
            '/' => .div,
            else => unreachable,
        },
    };
}

fn parseScope(self: *Parser) Error!Value {
    const token = self.tokens[self.cursor];
    if (token.kind != .open and token.kind != .close) return Error.ParseError;

    return Value{
        .scope = switch (self.buffer[token.start.?]) {
            '(' => .open,
            ')' => .close,
            else => unreachable,
        },
    };
}

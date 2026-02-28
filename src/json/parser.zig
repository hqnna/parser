const Parser = @This();
const std = @import("std");
const Tokenizer = @import("tokenizer.zig");

cursor: usize,
buffer: []const u8,
tokens: []const Tokenizer.Token,
allocator: std.mem.Allocator,

pub const Error =
    std.mem.Allocator.Error ||
    std.fmt.ParseIntError ||
    std.fmt.ParseFloatError ||
    error{ParseError};

pub const Value = union(enum(u8)) {
    object: std.StringHashMap(Value),
    array: std.ArrayList(Value),
    string: []const u8,
    number: f64,
    boolean: bool,
    null: void,

    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .object => |*obj| {
                var it = obj.iterator();
                while (it.next()) |v| v.value_ptr.deinit(allocator);
                obj.deinit();
            },
            .array => |*arr| {
                for (arr.items) |*i| i.deinit(allocator);
                arr.deinit(allocator);
            },
            .string => |s| allocator.free(s),
            else => return,
        }
    }
};

pub fn init(allocator: std.mem.Allocator, tokenizer: *Tokenizer) Error!Parser {
    var tokens = try std.ArrayList(Tokenizer.Token).initCapacity(allocator, 5);
    defer tokens.deinit(allocator);

    while (tokenizer.next()) |t| if (t.kind != .space)
        try tokens.append(allocator, t);

    return .{
        .allocator = allocator,
        .tokens = try tokens.toOwnedSlice(allocator),
        .buffer = tokenizer.buffer,
        .cursor = 0,
    };
}

pub fn deinit(self: Parser) void {
    self.allocator.free(self.tokens);
}

pub fn parseValue(self: *Parser) Error!Value {
    const token = self.tokens[self.cursor];

    const value = switch (token.kind) {
        .null => Value.null,
        .boolean => Value{ .boolean = std.mem.eql(u8, self.buffer[token.start.? .. token.end.? + 1], "true") },
        .number => Value{ .number = try std.fmt.parseFloat(f64, self.buffer[token.start.? .. token.end.? + 1]) },
        .string => Value{ .string = try self.allocator.dupe(u8, self.buffer[token.start.?..token.end.?]) },
        .arr_open => try self.parseArray(),
        .obj_open => try self.parseObject(),
        else => return Error.ParseError,
    };

    self.cursor += 1;
    return value;
}

pub fn parseArray(self: *Parser) Error!Value {
    var array = try std.ArrayList(Value).initCapacity(self.allocator, 0);
    errdefer array.deinit(self.allocator);

    if (self.tokens[self.cursor].kind != .arr_open) return Error.ParseError;
    self.cursor += 1;

    while (self.cursor < self.tokens.len) : (self.cursor += 1) {
        if (self.tokens[self.cursor].kind == .arr_close) break;
        try array.append(self.allocator, try self.parseValue());
        if (self.tokens[self.cursor].kind == .arr_close) break;
        if (self.tokens[self.cursor].kind != .comma) return Error.ParseError;
    }

    return Value{ .array = array };
}

pub fn parseObject(self: *Parser) Error!Value {
    var map = std.StringHashMap(Value).init(self.allocator);
    errdefer map.deinit();

    if (self.tokens[self.cursor].kind != .obj_open) return Error.ParseError;
    self.cursor += 1;

    while (self.cursor < self.tokens.len) : (self.cursor += 1) {
        if (self.tokens[self.cursor].kind == .obj_close) break;
        if (self.tokens[self.cursor].kind != .string) return Error.ParseError;

        const entry_name = (try self.parseValue()).string;

        if (self.tokens[self.cursor].kind != .colon) return Error.ParseError;
        self.cursor += 1;

        try map.put(entry_name, try self.parseValue());

        if (self.tokens[self.cursor].kind == .obj_close) break;
        if (self.tokens[self.cursor].kind != .comma) return Error.ParseError;
    }

    return Value{ .object = map };
}

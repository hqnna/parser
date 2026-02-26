const ASTGen = @This();
const std = @import("std");
const Parser = @import("parser.zig");

pub const Node = union(enum(u8)) {
    value: usize,
    operation: struct {
        op: Parser.Value.Operator,
        lhs: *Node,
        rhs: *Node,
    },

    pub fn deinit(self: Node, allocator: std.mem.Allocator) void {
        if (self == .value) return;
        self.operation.lhs.deinit(allocator);
        self.operation.rhs.deinit(allocator);
        allocator.destroy(self.operation.lhs);
        allocator.destroy(self.operation.rhs);
    }
};

cursor: usize,
values: []const Parser.Value,
allocator: std.mem.Allocator,

pub const Error = std.mem.Allocator.Error || error{Unexpected};

pub fn init(allocator: std.mem.Allocator, values: []const Parser.Value) ASTGen {
    return .{ .cursor = 0, .values = values, .allocator = allocator };
}

pub fn factor(self: *ASTGen) Error!*Node {
    const node = try self.allocator.create(Node);
    errdefer self.allocator.destroy(node);

    switch (self.values[self.cursor]) {
        .number => |v| node.* = Node{ .value = v },
        .scope => |v| {
            if (v != .open) return Error.Unexpected;
            self.cursor += 1;
            const expr_node = try self.expr();
            self.cursor += 1;
            return expr_node;
        },
        else => @panic("fuck this"),
    }

    self.cursor += 1;
    return node;
}

pub fn term(self: *ASTGen) Error!*Node {
    const lhs = try self.factor();

    while (self.cursor < self.values.len and self.values[self.cursor] == .operator) {
        const op = self.values[self.cursor].operator;

        switch (op) {
            .mul, .div => {
                self.cursor += 1;
                const rhs = try self.factor();
                const ptr = try self.allocator.create(Node);
                errdefer self.allocator.destroy(ptr);
                ptr.* = lhs.*;

                lhs.* = Node{ .operation = .{ .op = op, .lhs = ptr, .rhs = rhs } };
            },
            else => break,
        }
    }

    return lhs;
}

pub fn expr(self: *ASTGen) Error!*Node {
    const lhs = try self.term();

    while (self.cursor < self.values.len and self.values[self.cursor] == .operator) {
        const op = self.values[self.cursor].operator;

        switch (op) {
            .add, .sub => {
                self.cursor += 1;
                const rhs = try self.term();
                const ptr = try self.allocator.create(Node);
                errdefer self.allocator.destroy(ptr);
                ptr.* = lhs.*;

                lhs.* = Node{ .operation = .{ .op = op, .lhs = ptr, .rhs = rhs } };
            },
            else => break,
        }
    }

    return lhs;
}

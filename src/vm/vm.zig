const VM = @This();
const Value = @import("parser.zig").Value;
const Node = @import("astgen.zig").Node;

tree: *Node,

pub const Error = error{DivideByZero};

pub fn init(node: *Node) VM {
    return .{ .tree = node };
}

pub fn exec(self: VM) Error!Value {
    return self.eval(self.tree);
}

fn eval(self: VM, node: *Node) Error!Value {
    switch (node.*) {
        .value => |v| return Value{ .number = v },
        .operation => |op| {
            const lhs = try self.eval(op.lhs);
            const rhs = try self.eval(op.rhs);

            switch (lhs.number) {
                .int => |l| switch (rhs.number) {
                    .int => |r| return compute(isize, op.op, l, r),
                    .float => |r| return compute(f64, op.op, @floatFromInt(l), r),
                },
                .float => |l| switch (rhs.number) {
                    .int => |r| return compute(f64, op.op, l, @floatFromInt(r)),
                    .float => |r| return compute(f64, op.op, l, r),
                },
            }
        },
    }
}

fn compute(comptime T: type, op: Value.Operator, l: T, r: T) Error!Value {
    return switch (T) {
        isize => Value{ .number = .{ .int = switch (op) {
            .add => l + r,
            .sub => l - r,
            .mul => l * r,
            .div => if (r == 0) return Error.DivideByZero else @divTrunc(l, r),
        } } },
        f64 => Value{ .number = .{ .float = switch (op) {
            .add => l + r,
            .sub => l - r,
            .mul => l * r,
            .div => l / r,
        } } },
        else => unreachable,
    };
}

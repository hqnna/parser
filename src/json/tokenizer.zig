const Tokenizer = @This();
const std = @import("std");

pub const Token = struct {
    pub const Kind = enum(u8) {
        obj_open,
        obj_close,
        arr_open,
        arr_close,
        boolean,
        string,
        number,
        colon,
        comma,
        space,
        null,
    };

    kind: Kind,
    start: ?usize,
    end: ?usize,
};

cursor: usize,
buffer: []const u8,

pub fn init(data: []const u8) Tokenizer {
    return .{ .cursor = 0, .buffer = data };
}

pub fn next(self: *Tokenizer) ?Token {
    if (self.cursor >= self.buffer.len) return null;
    const token = self.getObject() orelse
        self.getArray() orelse
        self.getString() orelse
        self.getNumber() orelse
        self.getOperator() orelse
        self.getBool() orelse
        self.getNull() orelse
        self.getSpace();
    return token;
}

fn getObject(self: *Tokenizer) ?Token {
    const token = Token{
        .kind = switch (self.buffer[self.cursor]) {
            '{' => Token.Kind.obj_open,
            '}' => Token.Kind.obj_close,
            else => return null,
        },
        .start = self.cursor,
        .end = self.cursor,
    };
    self.cursor += 1;
    return token;
}

fn getArray(self: *Tokenizer) ?Token {
    const token = Token{
        .kind = switch (self.buffer[self.cursor]) {
            '[' => Token.Kind.arr_open,
            ']' => Token.Kind.arr_close,
            else => return null,
        },
        .start = self.cursor,
        .end = self.cursor,
    };
    self.cursor += 1;
    return token;
}

fn getSpace(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .space, .start = null, .end = null };

    while (self.cursor < self.buffer.len) : (self.cursor += 1) {
        switch (self.buffer[self.cursor]) {
            '\r', '\n', '\t', ' ' => {},
            else => break,
        }
        if (token.start == null) token.start = self.cursor;
        token.end = self.cursor;
    }

    if (token.start == null or token.end == null) return null;
    return token;
}

fn getString(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .string, .start = null, .end = null };
    if (self.buffer[self.cursor] != '"') return null;
    self.cursor += 1;

    token.start = self.cursor;
    while (self.cursor < self.buffer.len) : (self.cursor += 1) {
        switch (self.buffer[self.cursor]) {
            '\\' => self.cursor += 1,
            '\n' => return null,
            '"' => break,
            else => {},
        }
    }

    if (self.buffer[self.cursor] != '"') return null;
    token.end = self.cursor;
    self.cursor += 1;
    return token;
}

fn getOperator(self: *Tokenizer) ?Token {
    const token = switch (self.buffer[self.cursor]) {
        ':' => Token{ .kind = .colon, .start = self.cursor, .end = self.cursor },
        ',' => Token{ .kind = .comma, .start = self.cursor, .end = self.cursor },
        else => return null,
    };
    self.cursor += 1;
    return token;
}

fn getNumber(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .number, .start = null, .end = null };

    var char = self.buffer[self.cursor];
    if (char != '-' and !std.ascii.isDigit(char)) return null;
    token.start = self.cursor;
    self.cursor += 1;

    var is_float = false;
    var has_exponent = false;

    while (self.cursor < self.buffer.len) : (self.cursor += 1) {
        char = self.buffer[self.cursor];
        if (std.ascii.isDigit(char)) continue;
        if (has_exponent and (char == '+' or char == '-')) continue;

        if (char == '.') {
            if (is_float) return null;
            is_float = true;
            continue;
        }

        if (char == 'e' or char == 'E') {
            if (has_exponent) return null;
            has_exponent = true;
            continue;
        }

        break;
    }

    token.end = self.cursor - 1;
    return token;
}

fn getBool(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .boolean, .start = null, .end = null };

    if (self.cursor + 4 >= self.buffer.len) return null;
    if (std.mem.eql(u8, self.buffer[self.cursor .. self.cursor + 4], "true")) {
        token.start = self.cursor;
        token.end = self.cursor + 3;
        self.cursor += 4;
        return token;
    }

    if (self.cursor + 5 >= self.buffer.len) return null;
    if (std.mem.eql(u8, self.buffer[self.cursor .. self.cursor + 5], "false")) {
        token.start = self.cursor;
        token.end = self.cursor + 4;
        self.cursor += 5;
        return token;
    }

    return null;
}

fn getNull(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .null, .start = null, .end = null };

    if (self.cursor + 4 >= self.buffer.len) return null;
    if (!std.mem.eql(u8, self.buffer[self.cursor .. self.cursor + 4], "null")) return null;

    token.start = self.cursor;
    token.end = self.cursor + 3;
    self.cursor += 4;
    return token;
}

const Tokenizer = @This();

pub const Token = struct {
    pub const Kind = enum(u8) {
        operator,
        number,
        space,
        close,
        open,
    };

    kind: Kind,
    start: ?usize,
    end: ?usize,
};

buffer: []const u8,
cursor: usize,

pub fn init(data: []const u8) Tokenizer {
    return Tokenizer{ .buffer = data, .cursor = 0 };
}

pub fn next(self: *Tokenizer) ?Token {
    if (self.cursor >= self.buffer.len) return null;
    const token = self.getNumber() orelse
        self.getOperator() orelse
        self.getScope() orelse
        self.getSpace();
    return token;
}

fn getNumber(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .number, .start = null, .end = null };
    while (self.cursor < self.buffer.len) : (self.cursor += 1) {
        if (self.buffer[self.cursor] < '0' or self.buffer[self.cursor] > '9') break;
        if (token.start == null) token.start = self.cursor;
        token.end = self.cursor;
    }
    return if (token.start == null or token.end == null) null else token;
}

fn getOperator(self: *Tokenizer) ?Token {
    var token = Token{ .kind = .operator, .start = null, .end = null };
    return switch (self.buffer[self.cursor]) {
        '+', '-', '*', '/' => blk: {
            token.start = self.cursor;
            token.end = self.cursor;
            self.cursor += 1;
            break :blk token;
        },
        else => null,
    };
}

fn getScope(self: *Tokenizer) ?Token {
    const token = Token{
        .kind = switch (self.buffer[self.cursor]) {
            '(' => Token.Kind.open,
            ')' => Token.Kind.close,
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
    while (self.cursor < self.buffer.len) : (self.cursor += 1) switch (self.buffer[self.cursor]) {
        '\r', '\n', '\t', ' ' => {
            if (token.start == null) token.start = self.cursor;
            token.end = self.cursor;
        },
        else => break,
    };
    return if (token.start == null or token.end == null) null else token;
}

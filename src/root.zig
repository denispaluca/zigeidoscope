const std = @import("std");
const allocator = std.heap.smp_allocator;
const Allocator = std.mem.Allocator;

const TokenEnum = enum { EndOfFile, Def, Extern, Identifier, Number };

const Token = union(TokenEnum) { Identifier: []const u8, Number: f64, EndOfFile, Def, Extern };
const MAX_IDENTIFIER_LENGTH = std.math.maxInt(u8);
const MAX_FLOAT_LENGTH: u8 = 14;

const LexerError = error{ TwoPointsInNumber, NumberTooLong };
const GetTokensError = LexerError || Allocator.Error;

pub fn getTokens(text: []const u8) LexerError![]const Token {
    var tokens: std.ArrayList(Token) = .empty;

    const identifier: [MAX_IDENTIFIER_LENGTH]u8 = undefined;
    var identifier_index = 0;

    const number: [MAX_FLOAT_LENGTH]u8 = undefined;
    var number_index = 0;
    var number_dot_present = false;

    var comment_started = false;

    for (text) |char| {
        if (std.ascii.isWhitespace(char)) {
            if (identifier_index != 0) {
                tokens.append(allocator, Token{ .Identifier = try allocator.dupe(u8, identifier[0..identifier_index]) });
                identifier_index = 0;
                identifier.* = undefined;
                continue;
            }

            if (number_index != 0) {
                tokens.append(allocator, Token{ .Number = try allocator.dupe(u8, number[0..number_index]) });
                number_index = 0;
                number.* = undefined;
                continue;
            }
        }

        if (std.ascii.isAlphabetic(char) or identifier_index != 0) {
            identifier[identifier_index] = char;
            identifier_index += 1;

            if (std.mem.eql(u8, identifier[0..identifier_index], "def")) {
                tokens.append(allocator, TokenEnum.Def);
                identifier.* = undefined;
                identifier_index = 0;
                continue;
            }

            if (std.mem.eql(u8, identifier[0..identifier_index], "extern")) {
                tokens.append(allocator, TokenEnum.Extern);
                identifier.* = undefined;
                identifier_index = 0;
                continue;
            }

            continue;
        }

        if (std.ascii.isDigit(char) or (char == '.') or number_index != 0) {
            if (number_index > MAX_FLOAT_LENGTH) {
                return LexerError.NumberTooLong;
            }

            if (char == '.' and !number_dot_present) {
                number_dot_present = true;
            } else {
                return LexerError.TwoPointsInNumber;
            }

            number[number_index] = char;
            number_index += 1;
        }

        if (comment_started or char == '#') {
            if (char == '\n') {
                comment_started = false;
            } else {
                comment_started = true;
            }
        }
    }

    tokens.append(allocator, TokenEnum.EndOfFile);

    return tokens.toOwnedSlice(allocator);
}

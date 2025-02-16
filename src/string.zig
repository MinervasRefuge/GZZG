// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const Number = gzzg.Number;

//                                        ----------------
//                                        Character §6.6.3
//                                        ----------------

pub const Character = struct {
    s: guile.SCM,

    // zig fmt: off

    pub fn fromWideZ(a: i32) Character { return .{ .s = guile.SCM_MAKE_CHAR(a) }; }
    pub fn fromZ(a: u8) Character { return fromWideZ(@intCast(a)); }

    pub fn toWideZ(a: Character) i32 { return a.toNumber().toZ(i32); } // Macro broken guile.SCM_CHAR(a.s);
    pub fn toZ(a: Character) u8 { return a.toNumber().toZ(u8); }

    pub fn toNumber(a: Character) Number { return .{ .s = guile.scm_char_to_integer(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_char_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); } // where's the companion fn?

    pub fn isAlphabetic(a: Character) Boolean { return .{ .s = guile.scm_char_alphabetic_p(a.s) }; }
    pub fn isNumeric   (a: Character) Boolean { return .{ .s = guile.scm_char_numeric_p(a.s) }; }
    pub fn isWhitespace(a: Character) Boolean { return .{ .s = guile.scm_char_whitespace_p(a.s) }; }
    pub fn isUpperCase (a: Character) Boolean { return .{ .s = guile.scm_char_upper_case_p(a.s) }; }
    pub fn isLowerCase (a: Character) Boolean { return .{ .s = guile.scm_char_lower_case_p(a.s) }; }
    pub fn isBoth      (a: Character) Boolean { return .{ .s = guile.scm_char_is_both_p(a.s) }; }
        
    pub fn lowerZ(a: Character) Any { return .{ .s = a.s }; }

    pub fn generalCategory(a: Character) gzzg.UnionSCM(.{Symbol, Boolean}) {
        const gcat = guile.scm_char_general_category(a.s);
        
        return if (Boolean.isZ(gcat)) .{ .b = Boolean.FALSE } else .{ .a = .{ .s = gcat } };
    }

    pub fn equal           (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_eq_p(x.s, y.s) }; }
    pub fn lessThan        (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_less_p(x.s, y.s) }; }
    pub fn greaterThan     (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_gr_p(x.s, y.s) }; }
    pub fn lessThanEqual   (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_leq_p(x.s, y.s) }; }
    pub fn greaterThanEqual(x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_geq_p(x.s, y.s) }; }

    pub fn equalCI           (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_ci_eq_p(x.s, y.s) }; }
    pub fn lessThanCI        (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_ci_less_p(x.s, y.s) }; }
    pub fn greaterThanCI     (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_ci_gr_p(x.s, y.s) }; }
    pub fn lessThanEqualCI   (x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_ci_leq_p(x.s, y.s) }; }
    pub fn greaterThanEqualCI(x: Character, y: Character) Boolean { return .{ .s = guile.scm_char_ci_geq_p(x.s, y.s) }; }
    
    
    // zig fmt: on
};

//                                      --------------------
//                                      Character Set §6.6.4
//                                      --------------------

//                                          -------------
//                                          String §6.6.5
//                                          -------------

//todo: check string encoding perticulars.
pub const String = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn fromUTF8    (s: []const u8)   String { return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) }; }
    pub fn fromUTF8CStr(s: [:0]const u8) String { return .{ .s = guile.scm_from_utf8_string(s.ptr) }; }
    pub fn init(k: Number, chr: ?Character) String { return .{ .s = guile.scm_make_string(k.s, gzzg.orUndefined(chr)) }; }
    pub fn initZ(k: usize, chr: ?Character) String { return .{ .s = guile.scm_c_make_string(k.s, gzzg.orUndefined(chr)) }; }
    // zig fmt: on

    // Notes:
    // There does exist `scm_c_string_utf8_length` for knowing the number of bytes needed,
    // `scm_to_locale_stringbuf` is the only way to copy the string to your own managed mem copy.
    //         ^^^^^^ also double copies the string.
    // Only other way is via internal fns and/~ external char encoding libs.
    // `scm_i_string_chars (SCM str)` is public but has been marked for changing to internal only.

    // Note this code could be fragile ⚠
    const StrBuf = packed struct { tag: gzzg.altscm.SCMBits, len: usize, buffer: u8 };
    const Layout = packed struct { tag: gzzg.altscm.SCMBits, strbuf: *align(8) StrBuf };

    // string tests required
    // expect cons tag
    // expect cons.0 to be a string tag
    // expect cons.1 to be a cons tag
    // expect cons.1.0 to be stringbuf tag
    // expect const.1.0.1 to be a number,
    // expect cons.1.0.2 to be the buffer

    fn isDirect(s: gzzg.altscm.SCM) bool {
        const z = gzzg.altscm;

        if (!(!z.isImmediate(s) and z.getTCFor(z.TC3, s) == .cons))
            return false;

        const c0 = z.getSCMFrom(s[0]);
        const c1 = z.getSCMFrom(s[1]);

        if (!(z.isImmediate(c0) and
            z.getTCFor(z.TC3, c0) == .tc7 and
            z.getTCFor(z.TC7, c0) == .string and
            !z.isImmediate(c1) and
            z.getTCFor(z.TC3, c1) == .cons)) return false;

        const v0 = z.getSCMFrom(c1[0]);

        return z.isImmediate(v0) and
            z.getTCFor(z.TC3, v0) == .tc7_2 and
            z.getTCFor(z.TC7, v0) == .stringbuf;
    }

    fn getInternalBuffer(a: String, T: type) [:0]const T {
        switch (T) {
            u8, u32 => {},
            else => @compileError("Invalid internal string type: " ++ @typeName(T)),
        }

        const scm = gzzg.altscm; //todo: remove;
        const s: *align(8) Layout = @ptrCast(scm.getSCMFrom(@intFromPtr(a.s)));

        return @ptrCast(@as([*]const T, @ptrCast(&s.strbuf.buffer))[0..s.strbuf.len]);
    }

    pub fn getInternalStringSize(a: String) enum { narrow, wide } {
        const scm = gzzg.altscm; //todo: remove;
        const s: *align(8) Layout = @ptrCast(scm.getSCMFrom(@intFromPtr(a.s)));

        return if (s.strbuf.tag & guile.SCM_I_STRINGBUF_F_WIDE != 0) .wide else .narrow;
    }

    pub fn toUTF8(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        return if (@import("build_options").enable_direct_string_access)
            toUTF8Direct(a, allocator)
        else
            toUTF8Copy(a, allocator);
    }

    // recopy the c allocated one to zig mem
    fn toUTF8Copy(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        const cstr = std.mem.span(guile.scm_to_utf8_string(a.s));
        defer std.heap.raw_c_allocator.free(cstr);

        const out: [:0]u8 = @ptrCast(try allocator.alloc(u8, cstr.len));

        @memcpy(out, cstr);

        return out;
    }

    // direct mem access
    fn toUTF8Direct(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        // Codepoint ranges vs utf8 encoding
        //
        // 0x00000000 - 0x0000007F:
        //     0xxxxxxx
        //
        // 0x00000080 - 0x000007FF:
        //     110xxxxx 10xxxxxx
        //
        // 0x00000800 - 0x0000FFFF:
        //     1110xxxx 10xxxxxx 10xxxxxx
        //
        // 0x00010000 - 0x001FFFFF:
        //     11110xxx 10xxxxxx 10xxxxxx 10xxxxxx

        if (!isDirect(gzzg.altscm.getSCMFrom(@intFromPtr(a.s)))) return error.scmNotAString;

        switch (a.getInternalStringSize()) {
            .narrow => { // Latin-1
                // Latin-1 matches the same order of points as UTF-32/UCS-4
                const str_latin = a.getInternalBuffer(u8);

                var len_utf8: usize = 0;
                var multibyte_utf8 = false;
                for (0..str_latin.len) |ll| {
                    if (str_latin[ll] <= 0x7F) {
                        len_utf8 += 1;
                    } else {
                        multibyte_utf8 = true;
                        len_utf8 += 2;
                    }
                }

                var str_utf8: [:0]u8 = @ptrCast(try allocator.alloc(u8, len_utf8));
                errdefer allocator.free(str_utf8);

                if (multibyte_utf8) {
                    var pos_utf8: usize = 0;
                    var pos_latin: usize = 0;

                    while (pos_latin < str_latin.len) : ({
                        pos_latin += 1;
                        pos_utf8 += 1;
                    }) {
                        const char_latin = str_latin[pos_latin];

                        switch (char_latin) {
                            0x00...0x7F => str_utf8[pos_utf8] = char_latin,
                            0x80...0xFF => {
                                // Latin-1 is 1 byte => 8 bits
                                // UTF-8 2-byte usage is...
                                // 110---xx 10xxxxxx
                                str_utf8[pos_utf8] = 0b11000000 | char_latin >> 6;
                                pos_utf8 += 1;
                                str_utf8[pos_utf8] = 0b10000000 | (char_latin & 0b00111111);
                            },
                        }
                    }

                    //assert len written

                } else {
                    @memcpy(str_utf8, str_latin);
                }

                // double checking even though the source str is null terminated
                str_utf8[len_utf8] = 0;
                return str_utf8;
            },
            .wide => {
                const str_utf32 = a.getInternalBuffer(u32);

                var len_utf8: usize = 0;
                for (0..str_utf32.len) |ll| {
                    len_utf8 += switch (str_utf32[ll]) {
                        0x00000000...0x0000007F => 1,
                        0x00000080...0x000007FF => 2,
                        0x00000800...0x0000FFFF => 3,
                        0x00010000...0x001FFFFF => 4,
                        else => return error.scmStringNotValidUnicode,
                    };
                }

                var str_utf8: [:0]u8 = @ptrCast(try allocator.alloc(u8, len_utf8));
                errdefer allocator.free(str_utf8);

                var pos_utf8: usize = 0;
                var pos_utf32: usize = 0;

                while (pos_utf32 < str_utf32.len) : ({
                    pos_utf32 += 1;
                    pos_utf8 += 1;
                }) {
                    const char_utf32 = str_utf32[pos_utf32];

                    // zig fmt: off
                    switch (char_utf32) {
                        0x00000000...0x0000007F => str_utf8[pos_utf8] = @truncate(char_utf32),
                        0x00000080...0x000007FF => {
                            // 110xxxxx 10xxxxxx
                            str_utf8[pos_utf8] = 0b11000000 |
                                @as(u8, @truncate(char_utf32 >> 6));
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32)) & 0b00111111);
                        },
                        0x00000800...0x0000FFFF => {
                            // 1110xxxx 10xxxxxx 10xxxxxx
                            str_utf8[pos_utf8] = 0b11100000 |
                                @as(u8, @truncate(char_utf32 >> 12));
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32 >> 6)) & 0b00111111);
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32)) & 0b00111111);
                        },
                        0x00010000...0x001FFFFF => {
                            // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                            str_utf8[pos_utf8] = 0b11110000 |
                                @as(u8, @truncate(char_utf32 >> 18));
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32 >> 12)) & 0b00111111);
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32 >> 6)) & 0b00111111);
                            
                            pos_utf8 += 1;
                            str_utf8[pos_utf8] = 0b10000000 |
                                (@as(u8, @truncate(char_utf32)) & 0b00111111);
                        },
                        else => unreachable, // as per previous switch panic
                    }
                }
                // zig fmt: on

                //assert len written

                // double checking even though the source str is null terminated
                str_utf8[len_utf8] = 0;
                return str_utf8;
            },
        }
    }

    // zig fmt: off
    pub fn toSymbol(a: String) Symbol { return .{ .s = guile.scm_string_to_symbol(a.s) }; }

    pub fn toNumber(a: String, radix: ?Number) ?Number {
        const out = guile.scm_string_to_number(a.s, gzzg.orUndefined(radix));

        return if (Boolean.isZ(out)) null else .{ .s = out };
    }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_string_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_string(a) != 0; }

    pub fn isNull(a: String) Boolean { return .{ .s = guile.scm_string_null_p(a.s) }; }

    pub fn lowerZ(a: String) Any { return .{ .s = a.s }; }


    // §6.6.5.5 String Selection
    pub fn len (a: String) Number { return .{ .s = guile.scm_string_length(a.s) }; }
    pub fn lenZ(a: String) usize  { return guile.scm_c_string_length(a.s); }

    pub fn ref (a: String, k: Number) Character { return .{ .s = guile.scm_string_ref(a.s, k.s) }; }
    pub fn refZ(a: String, k: usize)  Character { return  .{ .s = guile.scm_c_string_ref(a.s, k) }; }
    //string-refz
    //string-copy
    //substring
    //substring/shared
    //substring/copy
    //substring/read-only
    //z
    //z
    //z
    //string-take
    //string-drop
    //string-take-right
    //string-drop-right
    //string-pad
    //stringpad-right
    //string-trim
    //string-trim-both
    //

    // string-any
    // string-ever

    pub fn iterator(a: String) ConstStringIterator {
        return .{
            .str = a,
            .len = a.lenZ(),
            .idx = 0
        };
    }
    
    // zig fmt: on
};

const ConstStringIterator = struct {
    str: String,
    len: usize,
    idx: usize,

    const Self = @This();

    pub fn next(self: *Self) ?Character {
        if (self.idx < self.len) {
            defer self.idx += 1;
            return self.str.refZ(self.idx);
        } else {
            return null;
        }
    }

    pub fn peek(self: *Self) ?Character {
        if (self.idx < self.len) {
            return self.str.refZ(self.idx);
        } else {
            return null;
        }
    }

    pub fn reset(self: *Self) void {
        self.idx = 0;
    }
};

//                                          -------------
//                                          Symbol §6.6.6
//                                          -------------

pub const Symbol = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn from    (s: []const u8)   Symbol { return .{ .s = guile.scm_from_utf8_symboln(s.ptr, s.len) }; }
    pub fn fromCStr(s: [:0]const u8) Symbol { return .{ .s = guile.scm_from_utf8_symbol(s.ptr) }; }

    pub fn toKeyword(a: Symbol) Keyword { return .{ .s = guile.scm_symbol_to_keyword(a.s) }; }
    pub fn toString (a: Symbol) Keyword { return .{ .s = guile.scm_symbol_to_string(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_symbol_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_symbol(a) != 0; } 

    pub fn lowerZ(a: Symbol) Any { return .{ .s = a.s }; }
    // zig fmt: on

    pub fn fromEnum(tag: anytype) Symbol {
        //todo: complete vs uncomplete enum?
        switch (@typeInfo(@TypeOf(tag))) {
            .Enum => {},
            else => @compileError("Expected enum varient"),
        }

        switch (tag) {
            inline else => |t| {
                const tns = @tagName(t);
                var str: [tns.len:0]u8 = undefined;

                inline for (tns, 0..) |c, i| {
                    str[i] = if (c == '_') '-' else c;
                }

                //loops don't cover the sentinel byte nor does the length. so +1
                str[tns.len] = 0;

                return Symbol.fromCStr(&str);
            },
        }
    }
};

//                                         --------------
//                                         Keyword §6.6.7
//                                         --------------

pub const Keyword = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn from(s: [:0]const u8) Keyword { return .{ .s = guile.scm_from_utf8_keyword(s) }; }

    pub fn toSymbol(a: Keyword) Symbol { return .{ .s = guile.scm_keyword_to_symbol(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_keyword_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_keyword(a) != 0; }

    // zig fmt: on
};

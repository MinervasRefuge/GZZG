// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const bopts = @import("build_options");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const orUndefined = gzzg.orUndefined;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Number  = gzzg.Number;

//                                        ----------------
//                                        Character §6.6.3
//                                        ----------------

pub const Character = struct {
    s: guile.SCM,

    //todo: fix to be u21
    pub fn fromWideZ(a: i32) Character { return .{ .s = guile.SCM_MAKE_CHAR(a) }; }
    pub fn fromZ(a: u8) Character { return fromWideZ(@intCast(a)); }

    pub fn toWideZ(a: Character) u21 { return @truncate(a.toNumber().toZ(u32)); } // Macro broken guile.SCM_CHAR(a.s);
    pub fn toZ(a: Character) !U8CharSlice { return .toUTF8(a.toWideZ()); }

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

    //

    pub fn format(value: Character, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(if (value.toZ())
                                |slice| slice.getConst()
                            else
                                |_| &iw.string.encoding.UTF32.replacement_character);
    }
    
    pub const U8CharSlice = struct {
        buffer: [4] u8,
        count: u3,

        pub fn getOne(self: *const @This()) u8 {
            if (self.count != 1)
                @panic("Attempted to get a char that wasn't one byte long");

            return self.buffer[0];
        }
        
        pub fn getConst(self: *const @This()) []const u8 {
            return self.buffer[0..self.count];
        }

        pub fn toUTF8(char: u21) !U8CharSlice {
            var slice: U8CharSlice = .{.buffer = undefined, .count = 0};
            slice.count = try std.unicode.utf8Encode(char, slice.buffer[0..]);
            return slice;
        }
    };
};

//                                      --------------------
//                                      Character Set §6.6.4
//                                      --------------------

//                                          -------------
//                                          String §6.6.5
//                                          -------------

pub const String = struct {
    s: guile.SCM,

    pub fn fromUTF8    (s: []const u8)   String { return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) }; }
    pub fn fromUTF8CStr(s: [:0]const u8) String { return .{ .s = guile.scm_from_utf8_string(s.ptr) }; }
    pub fn init(k: Number, chr: ?Character) String { return .{ .s = guile.scm_make_string(k.s, gzzg.orUndefined(chr)) }; }
    pub fn initZ(k: usize, chr: ?Character) String { return .{ .s = guile.scm_c_make_string(k.s, gzzg.orUndefined(chr)) }; }

    pub fn toUTF8(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        if (bopts.enable_direct_string_access) {
            // direct mem access
            const iw = gzzg.internal_workings;
            
            if (!iw.string.Layout.is(iw.gSCMtoIWSCM(a.s)))
                return error.scmNotAString;

            const s: *align(8) iw.string.Layout = .from(a);
            
            return s.getSlice().toUTF8(allocator);
        } else {
            // recopy the c allocated one to zig mem
            const cstr = std.mem.span(guile.scm_to_utf8_string(a.s));
            defer std.heap.raw_c_allocator.free(cstr);
            
            const out = try allocator.allocSentinel(u8, cstr.len, 0);
            
            @memcpy(out, cstr);
            
            return out;
        }
    }

    // todo: consider if the format fn should: exist, display or write
    pub fn format(value: String, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        if (bopts.enable_direct_string_access) {
            // direct mem access
            const iw = gzzg.internal_workings;
            
            if (!iw.string.Layout.is(iw.gSCMtoIWSCM(value.s))) return;
            // return error.scmNotAString;
            // todo: is there a way to return this error as it currently errors (explicit return type?)
            
            const s: *align(8) iw.string.Layout = .from(value);
        
            try s.getSlice().formatBuffer(fmt, options, writer);
        } else {
            var iter = value.iterator();
            
            while (iter.next()) |chr| {
                try std.fmt.format(writer, "{}", .{chr});            
            }
        }
    }

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
    pub fn substringE(a: String, start: Number, end:?Number) String {
        return .{ .s = guile.scm_substring(a.s, start.s, orUndefined(end)) };
    }
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

    pub fn from    (s: []const u8)   Symbol { return .{ .s = guile.scm_from_utf8_symboln(s.ptr, s.len) }; }
    pub fn fromCStr(s: [:0]const u8) Symbol { return .{ .s = guile.scm_from_utf8_symbol(s.ptr) }; }

    pub fn toKeyword(a: Symbol) Keyword { return .{ .s = guile.scm_symbol_to_keyword(a.s) }; }
    pub fn toString (a: Symbol) String  { return .{ .s = guile.scm_symbol_to_string(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_symbol_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_symbol(a) != 0; } 

    pub fn lowerZ(a: Symbol) Any { return .{ .s = a.s }; }

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

    pub fn from(s: [:0]const u8) Keyword { return .{ .s = guile.scm_from_utf8_keyword(s) }; }

    pub fn toSymbol(a: Keyword) Symbol { return .{ .s = guile.scm_keyword_to_symbol(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_keyword_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_keyword(a) != 0; }
};

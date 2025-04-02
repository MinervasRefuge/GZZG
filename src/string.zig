// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const bopts = @import("build_options");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType = gzzg.contracts.GZZGType;
const orUndefined = gzzg.orUndefined;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Integer = gzzg.Integer;
const ListOf  = gzzg.ListOf;
const Number  = gzzg.Number;

//                                        ----------------
//                                        Character §6.6.3
//                                        ----------------

pub const Character = struct {
    s: guile.SCM,

    pub const guile_name = "character";

    //todo: fix to be u21
    pub fn fromWideZ(a: i32) Character { return .{ .s = guile.SCM_MAKE_CHAR(a) }; }
    pub fn fromZ(a: u8) Character { return fromWideZ(@intCast(a)); }

    pub fn toWideZ(a: Character) u21 { return @truncate(a.toNumber().toZ(u32)); } // Macro broken guile.SCM_CHAR(a.s);
    pub fn toZ(a: Character) !U8CharSlice { return .toUTF8(a.toWideZ()); }

    pub fn toNumber(a: Character) Integer { return .{ .s = guile.scm_char_to_integer(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_char_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); } // where's the companion fn?

    pub fn isAlphabetic(a: Character) Boolean { return .{ .s = guile.scm_char_alphabetic_p(a.s) }; }
    pub fn isNumeric   (a: Character) Boolean { return .{ .s = guile.scm_char_numeric_p(a.s) }; }
    pub fn isWhitespace(a: Character) Boolean { return .{ .s = guile.scm_char_whitespace_p(a.s) }; }
    pub fn isUpperCase (a: Character) Boolean { return .{ .s = guile.scm_char_upper_case_p(a.s) }; }
    pub fn isLowerCase (a: Character) Boolean { return .{ .s = guile.scm_char_lower_case_p(a.s) }; }
    pub fn isBoth      (a: Character) Boolean { return .{ .s = guile.scm_char_is_both_p(a.s) }; }
        
    pub fn lowerZ(a: Character) Any { return .{ .s = a.s }; }

    pub fn generalCategory(a: Character) ?Symbol {
        const gcat = guile.scm_char_general_category(a.s);
        
        return if (Boolean.isZ(gcat)) null else .{ .s = gcat };
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
        const iw = gzzg.internal_workings;
        
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
            var slice: U8CharSlice = .{ .buffer = undefined, .count = 0 };
            slice.count = try std.unicode.utf8Encode(char, slice.buffer[0..]);
            return slice;
        }
    };

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

//                                      --------------------
//                                      Character Set §6.6.4
//                                      --------------------

//                                          -------------
//                                          String §6.6.5
//                                          -------------

pub const String = struct {
    s: guile.SCM,

    pub const guile_name = "string";
    
    pub fn fromUTF8    (s: []const u8)   String { return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) }; }
    pub fn fromUTF8CStr(s: [:0]const u8) String { return .{ .s = guile.scm_from_utf8_string(s.ptr) }; }
    pub fn fromListOfCharacters(a: ListOf(Character))        String { return .{ .s = guile.scm_string(a.s) }; }
    pub fn fromReverseListOfCharacters(a: ListOf(Character)) String { return .{ .s = guile.scm_reverse_list_to_string(a.s) }; }
    pub fn init (k: Integer, chr: ?Character) String { return .{ .s = guile.scm_make_string(k.s, gzzg.orUndefined(chr)) }; }
    pub fn initZ(k: usize, chr: ?Character)   String { return .{ .s = guile.scm_c_make_string(k.s, gzzg.orUndefined(chr)) }; }

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

    pub fn toUTF8UsingCAllocator(a: String) ![:0]u8 {
        return std.mem.span(guile.scm_to_utf8_string(a.s));
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
    pub fn toSymbolCI(a: String) Symbol { return .{ .s = guile.scm_string_ci_to_symbol(a.s) }; }

    pub fn toNumber(a: String, radix: ?Integer) ?Number {
        const out = guile.scm_string_to_number(a.s, gzzg.orUndefined(radix));

        return if (Boolean.isZ(out)) null else .{ .s = out };
    }

    pub fn toCharacters(a: String) ListOf(Character) { return .{ .s = guile.scm_string_to_list(a.s) }; }
    pub fn toCharactersSubString (a: String, start: Integer, end: ?Integer) ListOf(Character)
        { return .{ .s = guile.scm_substring_to_list(a.s, start.s, orUndefined(end)) }; }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_string_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_string(a) != 0; }

    pub fn isNull(a: String) Boolean { return .{ .s = guile.scm_string_null_p(a.s) }; }

    pub fn lowerZ(a: String) Any { return .{ .s = a.s }; }


    // §6.6.5.5 String Selection
    pub fn len (a: String) Integer { return .{ .s = guile.scm_string_length(a.s) }; }
    pub fn lenZ(a: String) usize  { return guile.scm_c_string_length(a.s); }

    pub fn ref (a: String, k: Integer) Character { return .{ .s = guile.scm_string_ref(a.s, k.s) }; }
    pub fn refZ(a: String, k: usize)  Character { return  .{ .s = guile.scm_c_string_ref(a.s, k) }; }
    //string-refz
    //string-copy
    pub fn substring(a: String, start: Integer, end: ?Integer) String {
        return .{ .s = guile.scm_substring(a.s, start.s, orUndefined(end)) };
    }

    pub fn substringShared(a: String, start: Integer, end: ?Integer) String {
        return .{ .s = guile.scm_substring_shared(a.s, start.s, orUndefined(end)) };
    }

    pub fn substringCopy(a: String, start: Integer, end: ?Integer) String {
        return .{ .s = guile.scm_substring_copy(a.s, start.s, orUndefined(end)) };
    }

    pub fn substringReadOnly(a: String, start: Integer, end: ?Integer) String {
        return .{ .s = guile.scm_substring_read_only(a.s, start.s, orUndefined(end)) };
    }

    // scm_c_substring
    // scm_c_substring_shared
    // scm_c_substring_copy
    // scm_c_substring_read_only

    pub const JoinGrammar = enum {
        const cache = gzzg.StaticCache(Symbol, &[_][]const u8{
            "infix", "strict-infix", "suffix", "prefix"
        });
        
        infix,
        strict_infix,
        suffix,
        prefix,

        pub fn get(a: @This()) Symbol {
            return switch(a) {
                .infix => cache.get("infix"),
                .strict_infix => cache.get("string-infix"),
                .suffix => cache.get("suffix"),
                .prefix => cache.get("prefix"),
            };
        }
        //todo: consider a Symbol -> JoinGrammar fn
    };
    
    pub fn join(a: ListOf(String), delimiter: ?Character, grammar: ?JoinGrammar) String {
        return .{ .s = guile.scm_string_join(
            a.s,
            orUndefined(delimiter),
            if (grammar == null) Any.UNDEFINED.s else grammar.?.get()
        )};
    }
    //string-tabulate

    pub fn take(a: String, n: Integer) String { return .{ .s = guile.scm_string_take(a.s, n.s) }; }
    pub fn drop(a: String, n: Integer) String { return .{ .s = guile.scm_string_drop(a.s, n.s) }; }
    pub fn takeRight(a: String, n: Integer) String { return .{ .s = guile.scm_string_take_right(a.s, n.s) }; }
    pub fn dropRight(a: String, n: Integer) String { return .{ .s = guile.scm_string_drop_right(a.s, n.s) }; }

    //string-pad
    //stringpad-right
    //string-trim
    //string-trim-both
    //

    // string-any
    // string-ever

    /// char_predicate can be a Character, Predicate, char set
    pub fn split(a: String, char_predicate: Any) GZZGType(@TypeOf(char_predicate), ListOf(String)) {
        return .{ .s = guile.scm_string_split(a.s, char_predicate.s) };
    }

    pub fn iterator(a: String) ConstStringIterator {
        return .{
            .str = a,
            .len = a.lenZ(),
            .idx = 0
        };
    }

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
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

// considered complete
pub const Symbol = struct {
    s: guile.SCM,

    pub const guile_name = "symbol";
    
    pub fn fromUTF8    (s: []const u8)   Symbol { return .{ .s = guile.scm_from_utf8_symboln(s.ptr, s.len) }; }
    pub fn fromUTF8CStr(s: [:0]const u8) Symbol { return .{ .s = guile.scm_from_utf8_symbol(s.ptr) }; }

    pub fn makeUninterned(a: String) Symbol { return .{ .s = guile.scm_make_symbol(a.s) }; }

    pub fn toKeyword(a: Symbol) Keyword { return .{ .s = guile.scm_symbol_to_keyword(a.s) }; }
    pub fn toString (a: Symbol) String  { return .{ .s = guile.scm_symbol_to_string(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_symbol_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_symbol(a) != 0; }
    pub fn lowerZ(a: Symbol) Any { return .{ .s = a.s }; }

    pub fn isInterned(a: Symbol) Boolean { return .{ .s = guile.scm_symbol_interned_p(a.s) }; }

    pub fn hash(a: Symbol) Integer { return .{ .s = guile.scm_symbol_hash(a.s) }; }
    pub fn lenZ(a: Symbol) usize { return guile.scm_c_symbol_length(a.s); }

    pub fn gensym(prefix: ?String) Symbol { return .{ .s = guile.scm_gensym(orUndefined(prefix)) }; }
    
    // todo: consider existance
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

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

//                                         --------------
//                                         Keyword §6.6.7
//                                         --------------

// considered done (bar the commented function)
pub const Keyword = struct {
    s: guile.SCM,

    pub const guile_name = "keyword";

    pub fn fromUTF8(s: [:0]const u8) Keyword { return .{ .s = guile.scm_from_utf8_keyword(s) }; }

    pub fn toSymbol(a: Keyword) Symbol { return .{ .s = guile.scm_keyword_to_symbol(a.s) }; }
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_keyword_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_keyword(a) != 0; }

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }

    //scm_c_bind_keyword_arguments
};

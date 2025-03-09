// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const string_encodings = @import("string_encoding.zig");
const bopts = @import("build_options");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;
const iw    = gzzg.internal_workings;

const CharacterWidth = string_encodings.CharacterWidth;

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
                                |_| &string_encodings.UTF32.replacement_character);
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

//todo: check string encoding perticulars.
pub const String = struct {
    s: guile.SCM,

    pub fn fromUTF8    (s: []const u8)   String { return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) }; }
    pub fn fromUTF8CStr(s: [:0]const u8) String { return .{ .s = guile.scm_from_utf8_string(s.ptr) }; }
    pub fn init(k: Number, chr: ?Character) String { return .{ .s = guile.scm_make_string(k.s, gzzg.orUndefined(chr)) }; }
    pub fn initZ(k: usize, chr: ?Character) String { return .{ .s = guile.scm_c_make_string(k.s, gzzg.orUndefined(chr)) }; }

    // Notes:
    // There does exist `scm_c_string_utf8_length` for knowing the number of bytes needed,
    // `scm_to_locale_stringbuf` is the only way to copy the string to your own managed mem copy.
    //         ^^^^^^ also double copies the string.
    // Only other way is via internal fns and/~ external char encoding libs.
    // `scm_i_string_chars (SCM str)` is public but has been marked for changing to internal only.

    // Note this code could be fragile ⚠
    const StrBuf = packed struct { tag: iw.SCMBits, len: usize, buffer: u8 };
    const Layout = packed struct { tag: iw.SCMBits, strbuf: *align(8) StrBuf };

    // string tests required
    // expect cons tag
    // expect cons.0 to be a string tag
    // expect cons.1 to be a cons tag
    // expect cons.1.0 to be stringbuf tag
    // expect const.1.0.1 to be a number,
    // expect cons.1.0.2 to be the buffer

    fn isDirect(s: iw.SCM) bool {
        if (!(!iw.isImmediate(s) and iw.getTCFor(iw.TC3, s) == .cons))
            return false;

        const c0 = iw.getSCMFrom(s[0]);
        const c1 = iw.getSCMFrom(s[1]);

        if (!(iw.isImmediate(c0) and
            iw.getTCFor(iw.TC3, c0) == .tc7 and
            iw.getTCFor(iw.TC7, c0) == .string and
            !iw.isImmediate(c1) and
            iw.getTCFor(iw.TC3, c1) == .cons))
            return false;

        const v0 = iw.getSCMFrom(c1[0]);

        return iw.isImmediate(v0) and
            iw.getTCFor(iw.TC3, v0) == .tc7_2 and
            iw.getTCFor(iw.TC7, v0) == .stringbuf;
    }

    fn getInternalBuffer(a: String, T: type) [:0]const T {
        switch (T) {
            u8, u21, u32 => {},
            else => @compileError("Invalid internal string type: " ++ @typeName(T)),
        }

        const s: *align(8) Layout = @ptrCast(iw.getSCMFrom(@intFromPtr(a.s)));

        return @ptrCast(@as([*]const T, @ptrCast(&s.strbuf.buffer))[0..s.strbuf.len]);
    }

    // todo: remove pub
    pub fn getInternalStringSize(a: String) CharacterWidth {
        const s: *align(8) Layout = @ptrCast(iw.getSCMFrom(@intFromPtr(a.s)));

        return if (s.strbuf.tag & guile.SCM_I_STRINGBUF_F_WIDE != 0) .wide else .narrow;
    }

    pub fn toUTF8(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        return if (bopts.enable_direct_string_access)
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
        if (!isDirect(iw.getSCMFrom(@intFromPtr(a.s)))) return error.scmNotAString;

        return switch (a.getInternalStringSize()) {
            .narrow => string_encodings.Latin1.toUTF8(allocator, a.getInternalBuffer(u8)),
            .wide   => string_encodings.UTF32 .toUTF8(allocator, a.getInternalBuffer(u32))
        };
    }

    // todo: add direct verions
    // todo: consider if the format fn should: exist, display or write
    // todo: format options
    pub fn format(value: String, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        if (bopts.enable_direct_string_access) {
            try formatFast(value, fmt, options, writer);
        } else {
            try formatSlow(value, fmt, options, writer);
        }
    }

    fn formatSlow(value: String, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var iter = value.iterator();

        while (iter.next()) |chr| {
            try std.fmt.format(writer, "{}", .{chr});            
        }
    }
    
    fn formatFast(value: String, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return switch (value.getInternalStringSize()) {
            .narrow => string_encodings.Latin1.writeToUTF8(value.getInternalBuffer(u8) , writer),
            .wide   => string_encodings.UTF32 .writeToUTF8(value.getInternalBuffer(u32), writer)
        };
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


//
// String & StringBuf Internals
//

// todo: move to a different file, Line in the sand between lib / custom implementation

fn assertTagSize(tag: type) void {
    if (@sizeOf(tag) != @sizeOf(iw.SCMBits) or @bitSizeOf(tag) != @bitSizeOf(iw.SCMBits)) {
        @compileError("Tag isn't a valid size");
    }
}

fn Padding(size: comptime_int) type {
    const T = std.builtin.Type;    
    
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.meta.Int(.unsigned, size),
            .fields = &[_]T.EnumField{.{.name = "nil", .value = 0}},
            .decls = &[_]T.Declaration{},
            .is_exhaustive = true,
        }
    });
}

//       TC7  TC3
// BA987 6543 210
// --------------
// 00010_0000_000  ==  Shared String      0x100
// 00100_0000_000  ==  Readonly String    0x200
// 01000_0000_000  ==  StringBuf wide     0x400
// 10000_0000_000  ==  StringBuf Mutable  0x800

pub const StringLayout = extern struct {
    tag: Tag,
    buffer: extern union {
        strbuf: *align(8) StringBufferUnknown,
        shared: *align(8) StringLayout
    },
    start: usize,
    len: usize,

    const Tag = packed struct {
        tc7: iw.TC7,
        _padding1: Padding(1) = .nil,
        shared: bool,
        read_only: bool,
        
        _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7 + 1 + 1 + 1)) = .nil,
        
        pub fn init(is_shared: bool, is_read_only: bool) @This() {
            return .{
                .tc7 = .string,
                .shared = is_shared,
                .read_only = is_read_only
            };
        }
        
        comptime { assertTagSize(@This()); }
    };
};

const StringBufferSlice = union {
    narrow: [:0]CharacterWidth.narrow.backingType(),
    wide: [:0]CharacterWidth.wide.backingType(),
};

pub fn StringBuffer(len: comptime_int, comptime backing: CharacterWidth) type {
    return extern struct{
        tag: StringBufferUnknown.Tag,
        len: usize = 0,
        buffer: [len:0] backing.backingType() = undefined,

        pub fn init(str_utf8: []const u8) !@This() {     
            var sb = @This(){
                .tag = .init(backing, false),
            };
            
            const written = try backing.encode(str_utf8, &sb.buffer);
            sb.len = written;
            sb.buffer[sb.len] = 0;

            return sb;
        }

        pub fn getSliceExact(self: *@This()) [:0]backing.backingType() {
            return &self.buffer;
        }

        pub fn getSlice(self: *@This()) StringBufferSlice {
            return switch (backing) {
                .wide => .{ .wide = &self.buffer },
                .narrow => .{ .narrow = &self.buffer },
            };
        }


    };
}

pub const StringBufferUnknown = extern struct {
    tag: Tag,
    len: usize,
    buffer: u8,

    pub fn getSlice(self: *@This()) StringBufferSlice {
        return switch (self.tag.wide) {
            .wide => 
                .{ .wide = @ptrCast(@as([*:0]const CharacterWidth.wide.backingType(),
                                               @ptrCast(&self.buffer))
                                               [0..self.len])},
            .narrow =>
                .{ .narrow = @ptrCast(@as([*:0]const CharacterWidth.narrow.backingType(),
                                        @ptrCast(&self.buffer))
                                        [0..self.len])},
        };
    }

    pub const Tag = packed struct {
        tc7: iw.TC7,
        _padding1: Padding(3) = .nil,
        width: CharacterWidth,
        mutable: bool,
        
        _padding2: Padding(@bitSizeOf(iw.SCMBits) - (7 + 3 + 1 + 1)) = .nil,
        
        pub fn init(char_width:CharacterWidth, is_mutable:bool) @This() {
            return .{
                .tc7 = .stringbuf,
                .width = char_width,
                .mutable = is_mutable
            };
        }
        
        comptime { assertTagSize(@This()); }
    };
};

pub fn StringBufferFrom(comptime str_utf8:[] const u8) type {
    const backing = string_encodings.CharacterWidth.fits(str_utf8)
        catch |err| @compileError(@errorName(err));
    const len_encoded = backing.lenIn(str_utf8);

    return StringBuffer(len_encoded, backing);
}

pub inline fn staticStringBuffer(comptime str_utf8:[] const u8) align(8) StringBufferFrom(str_utf8) {
    @setEvalBranchQuota(10_000); // how big?
    comptime { // is this the best way to hint that this is a comptime only function?
        return StringBufferFrom(str_utf8).init(str_utf8) catch |err| @compileError(@errorName(err));
    }
}

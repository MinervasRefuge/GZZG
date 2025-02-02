// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Boolean = gzzg.Boolean;
const Number = gzzg.Number;

//                                        ----------------
//                                        Character §6.6.3
//                                        ----------------

pub const Character = struct { s: guile.SCM };

//                                      --------------------
//                                      Character Set §6.6.4
//                                      --------------------

//                                          -------------
//                                          String §6.6.5
//                                          -------------

//todo: check string encoding perticulars.
pub const String = struct {
    s: guile.SCM,

    pub fn from(s: []const u8) String {
        return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) };
    }

    pub fn fromCStr(s: [:0]const u8) String {
        return .{ .s = guile.scm_from_utf8_string(s.ptr) };
    }

    pub fn toCStr(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        const l = a.lenZ();
        const buf = try allocator.alloc(u8, l + 1);
        const written = guile.scm_to_locale_stringbuf(a.s, buf.ptr, l);
        std.debug.assert(l == written);

        buf[l] = 0;
        return buf[0..l :0];
    }

    pub fn toZ(a: String, allocator: std.mem.Allocator) ![]u8 {
        const l = a.lenZ();
        const buf = try allocator.alloc(u8, l + 1); //todo +1?
        const written = guile.scm_to_locale_stringbuf(a.s, buf.ptr, l);
        std.debug.assert(l == written);

        return buf;
    }

    // string->number

    pub fn is(a: String) Boolean {
        return .{ .s = guile.scm_string_p(a.s) };
    }

    pub fn isZ(a: String) bool {
        return guile.scm_is_string(a.s) != 0;
    }

    pub fn len(a: String) Number {
        return .{ .s = guile.scm_string_length(a.s) };
    }

    pub fn lenZ(a: String) usize {
        return guile.scm_c_string_length(a.s);
    }
};

//                                          -------------
//                                          Symbol §6.6.6
//                                          -------------

pub const Symbol = struct {
    s: guile.SCM,

    pub fn from(s: []const u8) Symbol {
        return .{ .s = guile.scm_from_utf8_symboln(s.ptr, s.len) };
    }

    pub fn fromCStr(s: [:0]const u8) Symbol {
        return .{ .s = guile.scm_from_utf8_symbol(s.ptr) };
    }

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

pub const Keyword = struct { s: guile.SCM };

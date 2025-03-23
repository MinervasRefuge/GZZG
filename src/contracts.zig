// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std  = @import("std");
const gzzg = @import("gzzg.zig");

const SCM  = gzzg.guile.SCM;
const print = std.fmt.comptimePrint;

//
// Imports should be limited to only GZZG `type` checking code (with the exception of Guile `SCM`
// type above)
//

/// types that should be coercible into a []const u8
inline fn isStringType(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .pointer => |p| return switch (p.size) {
            .one => switch (@typeInfo(p.child)) {
                .array => |a| a.child == u8,
                else => false,
            },
            .slice => return p.child == u8,
            else => false,
        },
        .array => |a| return a.child == u8,
        else => return false,
    }
}

/// comptime values that can be coerced into a []const u8
/// taken from: https://ziggit.dev/t/how-to-check-if-something-is-a-string/5857/4
fn isString(comptime v: anytype) bool {
    const str: []const u8 = "";
    return @TypeOf(str, v) == []const u8;
}

fn gzzgType(comptime GT: type, comptime note: []const u8) void {
    const tname = @typeName(GT);
    switch (@typeInfo(GT)) {
        .@"struct" => |s| {
            if (s.is_tuple) @compileError(note ++ "SCMType " ++ tname ++ " can't be a tuple");

            if (std.meta.fieldIndex(GT, "s")) |s_idx| {
                if (s.fields[s_idx].type != SCM)
                    @compileError(note ++ "Expected `s` field to be a `guile.SCM`. Found: " ++
                                      @typeName(s.fields[s_idx].type));

                if (@hasDecl(GT, "Child") and @TypeOf(GT.Child) != type)
                    @compileError(note ++ "Expected `Child` to be a type on " ++ tname ++ ". Found: "
                                      ++ @typeName(@TypeOf(GT.Child)));

                if (!@hasDecl(GT, "guile_name"))
                    @compileError(note ++ "Missing human name `guile_name` on type: " ++ tname);

                if (!isStringType(@TypeOf(GT.guile_name)))
                    @compileError(note ++ "`guile_name` must be of a String: " ++ tname);
                                    
            } else {
                @compileError(note ++ "Missing `s: guile.SCM` field in: " ++ tname);
            }
        },
        else => @compileError(note ++ tname ++ " not a struct"),
    }
}

pub fn GZZGType(comptime GT: type, comptime Output: type) type {
    gzzgType(GT, "");

    return Output;
}

pub fn GZZGTypes(comptime GTs: type, comptime Output: type) type {
    switch (@typeInfo(GTs)) {
        .@"struct" => |st| {
            if (!st.is_tuple) @compileError("Expect tuple");
            inline for (st.fields, 0..) |f, i| {
                gzzgType(f.type, print("types@{d}: ", .{i}));
            }
        },
        else => @compileError("Not a tuple"),
    }

    return Output;
}

pub fn GZZGOptionalType(comptime OGT: type, comptime Output: type) type {
    switch (@typeInfo(OGT)) {
        .optional => |opt| {
            gzzgType(opt.child, "");
        },
        else => @compileError("Expected Optional Type"),
    }

    return Output;
}

pub fn GZZGFn(comptime FnGT: type, comptime Output: type) type {
    const ft = switch (@typeInfo(FnGT)) {
        .@"fn" => |st| st,
        else => @compileError("Not a Function"),
    };

    for (ft.params, 0..) |stp, i| {
        gzzgType(stp.type.?, print("fn parms@{d}: ", .{i}));
    }

    return Output;
}

pub fn GZZGFns(comptime FnGTs: type, comptime Output: type) type {
    switch (@typeInfo(FnGTs)) {
        .@"struct" => |st| {
            inline for (st.fields, 0..) |fn_type, i| {
                if (std.meta.fieldIndex(fn_type, "func") == null)
                    @compileError(print("fn@{d} missingx function", .{i}));

                const ft = switch (@typeInfo(fn_type)) {
                    .@"fn" => |f| f,
                    else => @compileError(print("Not a Function @{d}", .{i})),
                };

                for (ft.params, 0..) |stp, ii| {
                    gzzgType(stp.type.?, print("@{d}: fn parms@{d}: ", .{ i, ii }));
                }
            }
        },
        else => @compileError("Not a struct/tuple"),
    }

    return Output;
}

pub fn GZZGFnC(comptime FnCT: type, comptime Output: type) type {
    const ft = switch (@typeInfo(FnCT)) {
        .@"fn" => |st| st,
        else => @compileError("Not a Function"),
    };

    if (comptime !std.meta.eql(ft.calling_convention, .c))
        @compileError("fn must be using `.c` calling convention");

    for (ft.params, 0..) |stp, i| {
        gzzgType(stp.type, print("fn parms@{d}: ", .{i}));

        if (stp.type != gzzg.Any)
            @compileError(print("fn params@{d} must be of `Any` type", .{i}));
    }

    if (ft.return_type) |rty| {
        if (rty != gzzg.Any)
            @compileError("fn return type must be `Any` type");
    } else {
        @compileError("fn must have an `Any` return type");
    }

    return Output;
}

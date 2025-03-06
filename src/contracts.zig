// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const SCM = gzzg.guile.SCM;

const print = std.fmt.comptimePrint;

//
// Imports should be limited to only GZZG `type` checking code (with the exception of Guile `SCM` type above)
//

fn gzzgType(gt: type, comptime note: []const u8) void {
    const tname = @typeName(gt);
    switch (@typeInfo(gt)) {
        .@"struct" => |s| {
            if (s.is_tuple) @compileError(note ++ "SCMType " ++ tname ++ " can't be a tuple");

            if (std.meta.fieldIndex(gt, "s")) |s_idx| {
                if (s.fields[s_idx].type != SCM)
                    @compileError(note ++ "Expected `s` field to be a `guile.SCM`. Found: " ++ @typeName(s.fields[s_idx].type));
            } else {
                @compileError(note ++ "Missing `s: guile.SCM` field in: " ++ tname);
            }
        },
        else => @compileError(note ++ tname ++ " not a struct"),
    }
}

pub fn GZZGType(ts: type, output: type) type {
    gzzgType(ts, "");

    return output;
}

pub fn GZZGTypes(ts: type, output: type) type {
    switch (@typeInfo(ts)) {
        .@"struct" => |st| {
            inline for (st.fields, 0..) |f, i| {
                gzzgType(f.type, print("types@{d}: ", .{i}));
            }
        },
        else => @compileError("Not a struct/tuple"),
    }

    return output;
}

pub fn GZZGOptionalType(ot: type, output: type) type {
    switch (@typeInfo(ot)) {
        .optional => |opt| {
            gzzgType(opt.child, "");
        },
        else => @compileError("Expected Optional Type"),
    }

    return output;
}

pub fn GZZGFn(fn_type: type, output: type) type {
    const ft = switch (@typeInfo(fn_type)) {
        .@"fn" => |st| st,
        else => @compileError("Not a Function"),
    };

    for (ft.params, 0..) |stp, i| {
        gzzgType(stp.type.?, print("fn parms@{d}: ", .{i}));
    }

    return output;
}

pub fn GZZGFns(fn_types: type, output: type) type {
    switch (@typeInfo(fn_types)) {
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

    return output;
}

pub fn GZZGFnC(fn_type: type, output: type) type {
    const ft = switch (@typeInfo(fn_type)) {
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

    return output;
}

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType         = gzzg.contracts.GZZGType;
const GZZGTypes        = gzzg.contracts.GZZGTypes;
const GZZGOptionalType = gzzg.contracts.GZZGOptionalType;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Module  = gzzg.Module;
const String  = gzzg.String;
const Symbol  = gzzg.Symbol;

pub fn evalE(str: anytype, module: ?Module) Any {
    // string is expect to be in locale encoding
    // the c code just calls scm_from_locale_string.
    // _ = guile.scm_c_eval_string(…);
    // equv to the following

    //todo fix
    const gs = init: {
        switch (@typeInfo(@TypeOf(str))) {
            .Array => |a| {
                if (a.child != u8) @compileError("Array should have a sub type of u8");
                break :init String.fromUTF8(&str);
            },
            .Pointer => |p| {
                if (p.child != u8) @compileError("Slice should have a sub type of u8: " ++ @typeName(p.child));
                switch (p.size) {
                    .One => @compileError("Bad Pointer type"),
                    .Many => {
                        if (p.sentinel) |s| {
                            if (@as(*u8, @ptrCast(s)) != 0)
                                @compileError("Sentinel value must be 0");
                            break :init String.fromUTF8CStr(str);
                        } else {
                            @compileError("Many ptr must have sentinel of :0");
                        }
                    },
                    .Slice => break :init String.fromUTF8(str),
                    .C => break :init String.fromUTF8CStr(str),
                }
            },
            .Struct => {
                if (@TypeOf(str) != String)
                    @compileError("Struct should have been a `String`");

                break :init str;
            },
            else => @compileError("Not a string: " ++ @typeName(@TypeOf(str))),
        }
    };

    return .{ .s = guile.scm_eval_string_in_module(gs.s, orUndefined(module)) };
}

//                                      --------------------
//                                      General Utility §6.9
//                                      --------------------

pub fn eq(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eq_p(a.s, b.s) };
}

pub fn eqv(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

pub fn equal(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

// ~scm_is_eq~ is a macro that depends on ~SCM_UNPACK~ which didn't get translated due to ~volatile~ keyword. So...
// 
// C pointers should only be compared if they are elements of the same array or struct object. A
// round trip from ~void *~ to ~uintptr_t~ to ~void *~ is consider "safe". Hence the cast. Also see
// [[https://www.gnu.org/software/c-intro-and-ref/manual/html_node/Pointer_002dInteger-Conversion.html][c intro | pointer conversion]].
// 
// #+BEGIN_SRC c
//   typedef uintptr_t scm_t_bits;
//   #define SCM_UNPACK(x) ((scm_t_bits) (0? (*(volatile SCM *)0=(x)): x))
//   #define scm_is_eq(x, y) (SCM_UNPACK (x) == SCM_UNPACK (y))
// #+END_SRC
// 
// Zig allows ptr comparison as long as both types are the same ~&T == &T~ otherwise ~@intFromPtr~
// is the alternative. The equivalent with visual intent should be...

pub fn eqZ(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), bool) {
    return @intFromPtr(a.s) == @intFromPtr(b.s);
}

// todo: remember_upto_here
// todo: Fluids
// todo: Hooks

// todo: type check t
pub fn withContinuationBarrier(captures: anytype, comptime t: type) void {
    const ContinuationBarrierC = struct {
        fn barrier(data: ?*anyopaque) callconv(.c) ?*anyopaque {
            t.barrier(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }
    };

    //todo: check for null on exception and how exception should be handled
    _ = guile.scm_c_with_continuation_barrier(ContinuationBarrierC.barrier, @constCast(@ptrCast(&captures)));
}

pub fn newline() void {
    _ = guile.scm_newline(guile.scm_current_output_port());
}

pub fn display(a: anytype) GZZGType(@TypeOf(a), void) {
    _ = guile.scm_display(a.s, guile.scm_current_output_port());
}

pub fn newlineErr() void {
    _ = guile.scm_newline(guile.scm_current_error_port());
}

pub fn displayErr(a: anytype) GZZGTypes(@TypeOf(a), void) {
    _ = guile.scm_display(a.s, guile.scm_current_error_port());
}

//todo  ptr type checking
pub fn catchException(key: [:0]const u8, captures: anytype, comptime t: type) void {
    const ExpC = struct {
        fn body(data: ?*anyopaque) callconv(.c) guile.SCM {
            t.body(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }

        fn handler(data: ?*anyopaque, _key: guile.SCM, args: guile.SCM) callconv(.c) guile.SCM {
            t.handler(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))),
                      Symbol{ .s = _key },
                      Any{ .s = args });

            return guile.SCM_UNDEFINED;
        }
    };

    _ = guile.scm_internal_catch(Symbol.from(key).s,
                                 ExpC.body   , @constCast(@ptrCast(&captures)),
                                 ExpC.handler, @constCast(@ptrCast(&captures)));
}

pub fn orUndefined(a: anytype) GZZGOptionalType(@TypeOf(a), guile.SCM) {
    return if (a == null) Any.UNDEFINED.s else a.?.s;
}

pub fn StaticCache(GType: type, strs: []const []const u8) type {
    return struct {
        var container = [1]?GType{null} ** strs.len;

        fn index(comptime str: []const u8) usize {
            for (strs, 0..) |in_str, idx| {
                if (std.mem.eql(u8, in_str, str))
                    return idx;
            }

            @compileError("Not an member of the static lookup: " ++ str);
        }

        pub fn get(comptime str: []const u8) GType {
            const idx = comptime index(str);

            if (container[idx] == null) {
                container[idx] = GType.from(str);
            }

            return container[idx].?;
        }
    };
}

fn guileToZigName(comptime name: [:0]const u8) [name.len:0]u8 {
    var out: [name.len:0]u8 = undefined;

    //todo: consider capitals
    for (name, 0..) |c, i| {
        switch (c) {
            '-' => out[i] = '_',
            else => out[i] = c,
        }
    }

    return out;
}

/// Takes in a tuple of scm container types
pub fn UnionSCM(comptime scmTypes: anytype) GZZGTypes(scmTypes, type) {
    const Type = std.builtin.Type;
    const len = scmTypes.len + 1;

    var enum_fields: [len]Type.EnumField = undefined;
    var union_fields: [len]Type.UnionField = undefined;

    inline for (scmTypes, 0..) |St, i| {
        const name:[:0]const u8 = &guileToZigName(St.guile_name); // is this safe?
        
        enum_fields [i] = .{ .name = name, .value = i };
        union_fields[i] = .{ .name = name, .type = St, .alignment = @alignOf(guile.SCM) };
    }

    enum_fields [len-1] = .{ .name = Any.guile_name, .value = len-1 };
    union_fields[len-1] = .{ .name = Any.guile_name, .type = Any, .alignment = @alignOf(guile.SCM) };

    const SCMEnum = @Type(.{
        .Enum = .{
            .tag_type = std.math.IntFittingRange(0, len),
            .fields = &enum_fields,
            .decls = &[_]Type.Declaration{},
            .is_exhaustive = true
    }});

    const SCMUnion = @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = SCMEnum,
            .fields = &union_fields,
            .decls = &[_]Type.Declaration{}
    }});
 
    return struct {
        s: guile.SCM,

        pub fn get(a: @This(), comptime SCMType: type) ?SCMType {
            if (comptime std.mem.indexOfScalar(type, scmTypes, SCMType) == null)
                @compileError(@typeName(SCMType) ++ " not a member of this scm union");

            return if (SCMType.isZ(a.s)) .{ .s = a.s } else null;
        }

        pub fn decide(a: @This()) SCMUnion {
            inline for(std.meta.fields(SCMUnion)) |field| {
                if (comptime !std.mem.eql(u8, field.name, Any.guile_name))
                    if (field.type.isZ(a.s)) @unionInit(SCMUnion, field.name, .{ .s = a.s });
            }

            return @unionInit(SCMUnion, Any.guile_name, .{ .s = a.s });
        }

        pub fn lowerZ(a: @This()) Any { return .{ .s = a.s }; }
    };
}

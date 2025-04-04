// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType  = gzzg.contracts.GZZGType;
const GZZGTypes = gzzg.contracts.GZZGTypes;
const GZZGFn    = gzzg.contracts.GZZGFn;
const GZZGFns   = gzzg.contracts.GZZGFns;
const GZZGFnC   = gzzg.contracts.GZZGFnC;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const List    = gzzg.List;
const String  = gzzg.String;
const Symbol  = gzzg.Symbol;


pub const Module = struct {
    s: guile.SCM,

    pub const guile_name = "module";
    
    //todo type check
    pub fn define(name: [:0]const u8, define_fn: anytype) Module {
        const f = struct {
            pub fn cModuleDefine(_: ?*anyopaque) callconv(.c) void {
                define_fn();
            }
        };
        
        return .{ .s = guile.scm_c_define_module(name, f.cModuleDefine, null) };
    }

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

// todo: cover 6.18.10 Accessing Modules from C
pub const Procedure = struct {    
    s: guile.SCM,

    pub const guile_name = "procedure";
    const Symbols = gzzg.StaticCache(Symbol, Symbol.fromUTF8, &.{"documentation", "type-parameter"});
    
    //                               ---------------------------
    //                               Primitive Procedures §6.7.2
    //                               ---------------------------

    pub fn define(fn_name: [:0]const u8, comptime ff: anytype, fn_documentation: ?[:0]const u8, @"export": bool) GZZGFn(@TypeOf(ff), Procedure) {
        const ft = @typeInfo(@TypeOf(ff)).@"fn";

        if (ft.params.len > guile.SCM_GSUBR_MAX)
            @compileError(std.fmt.comptimePrint("Fn exceeds max parameter length of: {d}", .{guile.SCM_GSUBR_MAX}));

        const gp = guile.scm_c_define_gsubr(fn_name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(wrapZig(ff))));

        //todo: consider adding @src() details (is there a nice way to do it as @src() refers to the current location)
        if (fn_documentation) |docs| {
            _ = guile.scm_set_procedure_property_x(gp, Symbols.get("documentation").s, String.fromUTF8(docs).s);
        }

        if (@"export") {
            guile.scm_c_export(fn_name, guile.NULL);
        }

        return .{ .s = gp };
    }
    
    pub fn defineC(fn_name: [:0]const u8, comptime ff: anytype, fn_documentation: ?[:0]const u8, @"export": bool) GZZGFnC(@TypeOf(ff), Procedure) {
        const ft = @typeInfo(@TypeOf(ff)).@"fn";

        if (ft.params.len > guile.SCM_GSUBR_MAX)
            @compileError(std.fmt.comptimePrint("Fn exceeds max parameter length of: {d}", .{guile.SCM_GSUBR_MAX}));

        const gp = guile.scm_c_define_gsubr(fn_name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(&ff)));

        //todo: consider adding @src() details (is there a nice way to do it as @src() refers to the current location)
        if (fn_documentation) |docs| {
            _ = guile.scm_set_procedure_property_x(gp, Symbols.get("documentation").s, String.fromUTF8(docs).s);
        }

        if (@"export") {
            guile.scm_c_export(fn_name, guile.NULL);
        }

        return .{ .s = gp };
    }

    pub fn defineBulk(comptime fn_outlines: anytype) GZZGFns(@TypeOf(fn_outlines), [fn_outlines.len]Procedure) {
        var out: [fn_outlines.len]Procedure = undefined;

        //todo: check name exists?
        inline for (fn_outlines, 0..) |definition, idx| {
            const doc = if (@hasField(@TypeOf(definition), "doc")) definition.doc else null;
            const exp = if (@hasField(@TypeOf(definition), "export")) definition.@"export" else true;

            out[idx] = define(definition.name, definition.func, doc, exp);
        }

        return out;
    }

    pub fn is (a: guile.SCM)    Boolean { return .{ .s = guile.scm_procedure_p(a) }; }
    pub fn isZ(a: guile.SCM)    bool    { return is(a).toZ(); }
    pub fn lowerZ(a: Procedure) Any     { return .{ .s = a.s }; }

    //
    //

    //todo check if symbol or string
    pub fn name(a: Procedure) Symbol { return .{ .s = guile.scm_procedure_name(a.s) }; }
    pub fn source(a: Procedure) ?Any {
        const ps = guile.scm_procedure_source(a.s);
        
        return if (Boolean.is(ps)) null else .{ .s = ps };
    }
    
    // properties
    // property
    // propertiesX
    // propertyX

    pub fn documentation(a: Procedure) ?Any {
        const pd = guile.scm_procedure_documentation(a.s);

        //todo: check types
        if (Boolean.is(pd)) null else .{ .s = pd };
    }

    // todo: allow return type check
    pub fn call(proc: Procedure, args: anytype) GZZGTypes(@TypeOf(args), Any) {
        var scmArgs: [args.len]guile.SCM = undefined;
        
        inline for (0..args.len) |i| {
            scmArgs[i] = args[i].s;
        }
        
        return .{ .s = guile.scm_call_n(proc.s, &scmArgs, scmArgs.len) };
    }

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

pub fn ThunkOf(T: type) GZZGType(T, type) {
    return struct {
        s: guile.SCM,

        pub const guile_name = "thunk";

        pub fn is (a: guile.SCM)  Boolean { return .{ .s = guile.scm_thunk_p(a) }; }
        pub fn isZ(a: guile.SCM)  bool    { return is(a).toZ(); }
        pub fn lowerZ(a: @This()) Any     { return .{ .s = a.s }; }
        pub fn lowerProcedure(a: @This()) Procedure { return .{ .s = a.s }; }

        pub fn call(a: @This()) T {
            return .{ .s = guile.scm_call_0(a.s) };
        }

        comptime {
            _ = gzzg.contracts.GZZGType(@This(), void);
        }
    };
}

fn wrapZig(f: anytype) GZZGFn(@TypeOf(f), *const fn (...) callconv(.c) guile.SCM) {
    const fi = @typeInfo(@TypeOf(f)).@"fn";

    //todo: is there a better way of building a tuple for the `@call`?
    comptime var fields: [fi.params.len]std.builtin.Type.StructField = undefined;

    inline for (fi.params, 0..) |p, i| {
        fields[i] = std.builtin.Type.StructField{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = p.type.?, // optional for anytype?
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0
        };
    }

    const Args = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = true,
        },
    });

    return struct {
        //todo: use options as guile optional parms
        //todo: consider implicied type conversion guile.SCM => i32 (other then Number)
        //todo: return type of tuple as a scm_values returns
        fn wrapper(...) callconv(.c) guile.SCM {
            var args: Args = undefined;

            {
                var varg = @cVaStart();
                defer @cVaEnd(&varg);

                inline for (fi.params, 0..) |p, i| {
                    const pt = p.type.?;
                    const sva = @cVaArg(&varg, guile.SCM);

                    if (@hasDecl(pt, "isZ")) { // Common wrapped types
                        if (pt.isZ(sva)) {
                            args[i] = .{ .s = sva };
                        } else {
                            //todo: We can throw a better exception here...
                            guile.scm_throw(Procedure.Symbols.get("type-parameter").s, List.init(.{ String.fromUTF8(std.fmt.comptimePrint("Not a {s} at index {d}", .{ @typeName(pt), i })), Any{ .s = sva } }).s);
                        }
                    } else if (@hasDecl(pt, "assert")) { // Foreign Types
                        pt.assert(sva); // todo: fix, defer may not be run if the assert triggers
                        args[i] = .{ .s = sva };
                    } else if (p.type.? == guile.SCM) {
                        args[i] = sva;
                    } else {
                        @compileError("Unknown parm type for guile wrapper function: " ++
                            @typeName(pt) ++
                            " Did you forget to make `pub` for `usingnamespace gzzg.SetupFT`?");
                    }
                }
            }

            //todo: consider using `.always_inline`?
            const out = @call(.auto, f, args);

            //todo: simplify switch
            switch (@typeInfo(fi.return_type.?)) {
                .error_union => |eu| {
                    if (out) |ok| {
                        switch (eu.payload) {
                            void => {
                                return guile.SCM_UNDEFINED;
                            },
                            guile.SCM => {
                                return ok;
                            },
                            else => {
                                return ok.s; //todo: check that return is a scm wrapper
                            },
                        }
                    } else |err| {
                        //todo: format error name scm style (eg. dash over camel case)
                        guile.scm_throw(Symbol.fromUTF8(@errorName(err)).s, List.init(.{}).s);
                    }
                },
                else => {
                    switch (fi.return_type.?) {
                        void => {
                            return guile.SCM_UNDEFINED;
                        },
                        guile.SCM => {
                            return out;
                        },
                        else => {
                            return out.s; //todo: check that return is a scm wrapper
                        },
                    }
                },
            }
        }
    }.wrapper;
}

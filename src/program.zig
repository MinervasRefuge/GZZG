// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const List = gzzg.List;
const String = gzzg.String;
const Symbol = gzzg.Symbol;

// zig fmt: off
pub const Module = struct {
    s: guile.SCM
};


// todo: cover 6.18.10 Accessing Modules from C
pub const Procedure = struct {
    var _symbol_documentation:?Symbol = null;
    var _symbol_type_parameter:?Symbol = null;
    
    s: guile.SCM,

    //                               ---------------------------
    //                               Primitive Procedures §6.7.2
    //                               ---------------------------

    pub fn define(fn_name: [:0]const u8, comptime ff: anytype, fn_documentation: ?[:0]const u8, @"export": bool) Procedure {
        const ft = switch (@typeInfo(@TypeOf(ff))) {
            .@"fn" => |fs| fs,
            else => @compileError("Bad fn"), // todo: improve error
        };

        if (ft.params.len > guile.SCM_GSUBR_MAX)
            @compileError(std.fmt.comptimePrint("Fn exceeds max parameter length of: {d}", .{guile.SCM_GSUBR_MAX}));

        const gp = guile.scm_c_define_gsubr(fn_name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(wrapZig(ff))));

        //todo: consider adding @src() details (is there a nice way to do it as @src() refers to the current location)
        if (fn_documentation) |docs| {
            _ = guile.scm_set_procedure_property_x(gp, symbolDocumentation().s, String.fromUTF8(docs).s);
        }

        if (@"export") {
            guile.scm_c_export(fn_name, guile.NULL);
        }

        return .{ .s = gp };
    }
    
    pub fn defineC(fn_name: [:0]const u8, comptime ff: anytype, fn_documentation: ?[:0]const u8, @"export": bool) Procedure {
        const ft = switch (@typeInfo(@TypeOf(ff))) {
            .@"fn" => |fs| fs,
            else => @compileError("Bad fn"), // todo: improve error
        };

        if (ft.params.len > guile.SCM_GSUBR_MAX)
            @compileError(std.fmt.comptimePrint("Fn exceeds max parameter length of: {d}", .{guile.SCM_GSUBR_MAX}));
        
        if (comptime !std.meta.eql(ft.calling_convention, .c))
            @compileError("fn must be using `.c` calling convention");

        inline for (ft.params) |p| if (p.type != Any)
            @compileError("All parameters must be of `Any` type");
        
        if (ft.return_type) |rty| {
            if (rty != Any)
                @compileError("Return type must be `Any` type");
        } else {
            @compileError("Must have an `any` return type");
        }

        // todo: improve exception options.

        const gp = guile.scm_c_define_gsubr(fn_name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(&ff)));

        //todo: consider adding @src() details (is there a nice way to do it as @src() refers to the current location)
        if (fn_documentation) |docs| {
            _ = guile.scm_set_procedure_property_x(gp, symbolDocumentation().s, String.fromUTF8(docs).s);
        }

        if (@"export") {
            guile.scm_c_export(fn_name, guile.NULL);
        }

        return .{ .s = gp };
    }

    pub fn defineBulk(comptime fn_outlines: anytype) [fn_outlines.len]Procedure {
        var out: [fn_outlines.len]Procedure = undefined;

        inline for (fn_outlines, 0..) |definition, idx| {
            const doc = if (@hasField(@TypeOf(definition), "doc")) definition.doc else null;
            const exp = if (@hasField(@TypeOf(definition), "export")) definition.@"export" else true;

            out[idx] = define(definition.name, definition.func, doc, exp);
        }

        return out;
    }

    pub fn is (a: guile.SCM)  Boolean { return .{ .s = guile.scm_procedure_p(a) }; }
    pub fn isZ(a: guile.SCM)  bool    { return is(a).toZ(); }
    pub fn lowerZ(a: Boolean) Any     { return .{ .s = a.s }; }

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
    pub fn callE(proc: Procedure, args: anytype) Any {
        var scmArgs: [args.len]guile.SCM = undefined;
        
        inline for (0..args.len) |i| {
            gzzg.assertSCMType(@TypeOf(args[i]));
            scmArgs[i] = args[i].s;
        }
        
        return .{ .s = guile.scm_call_n(proc.s, &scmArgs, scmArgs.len) };
    }

    fn symbolDocumentation() Symbol {
        if (_symbol_documentation == null) {
            _symbol_documentation = Symbol.from("documentation");
        }

        return _symbol_documentation.?;
    }
    
    fn symbolTypeParameter() Symbol {
        if (_symbol_type_parameter == null) {
            _symbol_type_parameter = Symbol.from("type-parameter");
        }
        
        return _symbol_type_parameter.?;
    }
};

fn wrapZig(f: anytype) *const fn (...) callconv(.c) guile.SCM {
    const fi = switch (@typeInfo(@TypeOf(f))) {
        .@"fn" => |fi| fi,
        else => @compileError("Only wraps Functions"),
    }; //todo: could improve errors here.

    //todo: is there a better way of building a tuple for the `@call`?
    comptime var fields: [fi.params.len]std.builtin.Type.StructField = undefined;

    inline for (fi.params, 0..) |p, i| {
        // zig fmt: off
        fields[i] = std.builtin.Type.StructField{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = p.type.?, // optional for anytype?
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = 0
        };
        // zig fmt: on
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
        fn wrapper(...) callconv(.C) guile.SCM {
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
                            guile.scm_throw(Procedure.symbolTypeParameter().s, List.init(.{ String.fromUTF8("Not a " ++ @typeName(pt) ++ " at index " ++ std.fmt.comptimePrint("{d}", .{i})), Any{ .s = sva } }).s);
                        }
                    } else if (@hasDecl(pt, "assert")) { // Foreign Types
                        pt.assert(sva); // todo: fix, defer may not be run if the assert triggers
                        args[i] = .{ .s = sva };
                    } else if (p.type.? == guile.SCM) {
                        args[i] = sva;
                    } else {
                        @compileError("Unknown parm type for guile wrapper function: " ++ @typeName(pt) ++ " Did you forget to make `pub` for `usingnamespace gzzg.SetupFT`?");
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
                        guile.scm_throw(Symbol.from(@errorName(err)).s, List.init(.{}).s);
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

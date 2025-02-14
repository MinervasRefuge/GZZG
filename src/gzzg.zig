// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

pub const guile = @cImport({
    @cInclude("libguile.h");
});

//| boxes -d whirly -a c
//add 20 space indent

//                      .+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.
//                     (                                                     )
//                      ) G u i l e   T y p e :   D e f a u l t   T y p e s (
//                     (                                                     )
//                      "+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"

pub const GuileGCAllocator = struct {
    what: [:0]const u8,
    // todo: consider if it was a single threaded application. could it be worth creating a stack of `whats` that can
    // scoped to give more context?

    pub fn allocator(self: *GuileGCAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    // fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8
    fn alloc(ctx: *anyopaque, n: usize, _: u8, _: usize) ?[*]u8 {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(ctx));

        return @ptrCast(guile.scm_gc_malloc(n, self.what));
    }

    // fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool
    fn resize(ctx: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(ctx));

        _ = guile.scm_gc_realloc(buf.ptr, buf.len, new_len, self.what);
        @trap();
        //todo: fix and check resize alloc op.
        //return true;
    }

    // fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void
    fn free(ctx: *anyopaque, buf: []u8, _: u8, _: usize) void {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(ctx));

        guile.scm_gc_free(buf.ptr, buf.len, self.what);
    }
};

// §6.6 Data Types
// zig fmt: off
//pub const Any        = struct { s: guile.SCM };

pub const Boolean    = @import("boolean.zig").Boolean;
pub const Number     = @import("number.zig").Number;
pub const Character  = @import("string.zig").Character;
// Character Sets
pub const String     = @import("string.zig").String;
pub const Symbol     = @import("string.zig").Symbol;
pub const Keyword    = @import("string.zig").Keyword;
pub const Pair       = @import("list.zig").Pair;
pub const List       = @import("list.zig").List;
pub const Vector     = @import("vector.zig").Vector;
// Bit Vectors
pub const ByteVector = @import("byte_vector.zig").ByteVector;
//Arrays
//VLists
//Records
//Structures
//Association Lists
//VHashs
//pub const HashTable = SCMWrapper(null);

//
//

pub const Module      = struct { s: guile.SCM };
pub const Procedure   = struct { s: guile.SCM };
pub const ForeignType = struct { s: guile.SCM };

// zig fmt: on

// `to` implies conversion
// `as` implies change
// `from` is the reverse of `to` AToB <=> BFromA

// use `from` as a constructor for the guile type
// append `Z` if function returns zig values.
// append `X` for mutation functions (more-so based on scm function naming)
// append `E` if a known exception can be raised but isn't capture by the function
// CONST => from => to => is => lowerZ => other

pub fn assertSCMType(comptime t: type) void {
    switch (@typeInfo(t)) {
        .Struct => |s| {
            if (s.is_tuple) @compileError("SCMType " ++ @typeName(t) ++ " can't be a tuple");

            inline for (s.fields) |sf| {
                if (std.mem.eql(u8, sf.name, "s") and sf.type == guile.SCM) return;
            }

            @compileError("SCMType " ++ @typeName(t) ++ " missing valid SCM field");
        },
        else => @compileError("SCMType not a struct"),
    }
}

pub const Any = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn is (_: guile.SCM) Boolean { return Boolean.TRUE; } // what about `guile.SCM_UNDEFINED`?
    pub fn isZ(_: guile.SCM) bool    { return true; }

    pub fn lowerZ(a: Any) Any { return a; }
    // zig fmt: on

    pub fn raiseZ(a: Any, SCMType: type) ?SCMType {
        //todo: fix
        //assertSCMType(SCMType);

        if (!@hasDecl(SCMType, "isZ"))
            @compileError("Missing `isZ` for type narrowing (`raise`) on " ++ @typeName(SCMType));

        return if (SCMType.isZ(a.s)) .{ .s = a.s } else null;
    }
};

//                                       ------------------
//                                       Bit Vector §6.6.11
//                                       ------------------

//                                         --------------
//                                         Arrays §6.6.13
//                                         --------------

//                                          -------------
//                                          VList §6.6.14
//                                          -------------

//                                --------------------------------
//                                Record §6.6.15, §6.6.16, §6.6.17
//                                --------------------------------

//                                        -----------------
//                                        Structure §6.6.18
//                                        -----------------

//                                     -------------------------
//                                     Association Lists §6.6.20
//                                     -------------------------

//                                          -------------
//                                          VHash §6.6.21
//                                          -------------

//================================================+==================================================
//                                        -----------------
//                                        HashTable §6.6.22
//                                        -----------------

//                                   --------------------------
//                                   Primitive Procedures §6.7.2
//                                   --------------------------

fn typeExceptionSymbol() Symbol {
    const container = struct {
        var singleton: ?Symbol = null;
    };

    if (container.singleton == null) {
        container.singleton = Symbol.from("type-parameter");
    }

    return container.singleton.?;
}

fn wrapZig(f: anytype) *const fn (...) callconv(.C) guile.SCM {
    const fi = switch (@typeInfo(@TypeOf(f))) {
        .Fn => |fi| fi,
        else => @compileError("Only wraps Functions"),
    }; //todo: could improve errors here.

    //todo: is there a better way of building a tuple for the `@call`?
    comptime var fields: [fi.params.len]std.builtin.Type.StructField = undefined;

    inline for (fi.params, 0..) |p, i| {
        // zig fmt: off
        fields[i] = std.builtin.Type.StructField{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = p.type.?, // optional for anytype?
            .default_value = null,
            .is_comptime = false,
            .alignment = 0
        };
        // zig fmt: on
    }

    const Args = @Type(.{
        .Struct = .{
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
                            guile.scm_throw(typeExceptionSymbol().s, List.init(.{ String.from("Not a " ++ @typeName(pt) ++ " at index " ++ std.fmt.comptimePrint("{d}", .{i})), Any{ .s = sva } }).s);
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
                .ErrorUnion => |eu| {
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

pub fn defineGSubR(name: [:0]const u8, comptime ff: anytype, documentation: ?[:0]const u8) Procedure {
    const ft = switch (@typeInfo(@TypeOf(ff))) {
        .Fn => |fs| fs,
        else => @compileError("Bad fn"), // todo: improve error
    };

    const gp = guile.scm_c_define_gsubr(name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(wrapZig(ff))));

    //todo: consider adding @src() details (is there a nice way to do it as @src() refers to the current location)
    if (documentation != null) {
        _ = guile.scm_set_procedure_property_x(gp, Symbol.from("documentation").s, String.from(documentation.?).s);
    }

    return .{ .s = gp };
}

pub fn defineGSubRAndExport(name: [:0]const u8, comptime ff: anytype, documentation: ?[:0]const u8) Procedure {
    const scmf = defineGSubR(name, ff, documentation);

    guile.scm_c_export(name, guile.NULL);

    return scmf;
}

pub fn defineGSubRAndExportBulk(comptime gsubr_outlines: anytype) [gsubr_outlines.len]Procedure {
    var out: [gsubr_outlines.len]Procedure = undefined;

    inline for (gsubr_outlines, 0..) |definition, idx| {
        const doc = if (@hasField(@TypeOf(definition), "doc")) definition.doc else null;

        out[idx] = defineGSubRAndExport(definition.name, definition.func, doc);
    }

    return out;
}

// todo: allow return type check
// todo: exception handling from invalid args
pub fn call(proc: Procedure, args: anytype) Any {
    var scmArgs: [args.len]guile.SCM = undefined;

    inline for (0..args.len) |i| {
        scmArgs[i] = args[i].s;
    }

    return .{ .s = guile.scm_call_n(proc.s, &scmArgs, scmArgs.len) };
}

//                                      --------------------
//                                      General Utility §6.9
//                                      --------------------

//todo: typecheck
pub fn eq(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eq_p(a.s, b.s) };
}

//todo: typecheck
pub fn eqv(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

//todo: typecheck
pub fn equal(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

//todo: typecheck
pub fn eqZ(a: anytype, b: anytype) bool {
    return .{ .s = guile.scm_is_eq(a.s, b.s) };
}

//                                      ---------------------
//                                      Foreign Objects §6.20
//                                      ---------------------

pub fn makeForeignObjectType1(name: Symbol, slot: Symbol) ForeignType {
    return .{ .s = guile.scm_make_foreign_object_type(name.s, guile.scm_list_1(slot.s), null) };
}

//todo add checks
//todo: Foreign Objects are based on Goops (vtables). Consider method implementations?
//      See also src libguile/foreign-object.c
//      Consider look at guile structures since vtables are build on that too.
pub fn SetupFT(comptime ft: type, comptime cct: type, name: [:0]const u8, slot: [:0]const u8) type {
    return struct {
        var scmType: ForeignType = undefined;
        const CType: type = cct;

        pub fn assert(a: guile.SCM) void {
            guile.scm_assert_foreign_object_type(scmType.s, a);
            // ---------------------- libguile/foreign-object.c:72
            // void
            // scm_assert_foreign_object_type (SCM type, SCM val)
            // {
            //   /* FIXME: Add fast path for when type == struct vtable */
            //   if (!SCM_IS_A_P (val, type))
            //     scm_error (scm_arg_type_key, NULL, "Wrong type (expecting ~A): ~S",
            //                scm_list_2 (scm_class_name (type), val), scm_list_1 (val));
            // }
        }

        pub fn registerType() void {
            scmType = makeForeignObjectType1(Symbol.from(name), Symbol.from(slot));
        }

        pub fn makeSCM(data: *cct) ft {
            return .{ .s = guile.scm_make_foreign_object_1(scmType.s, data) };
        }

        // const mak = if (@sizeOf(cct) <= @sizeOf(*anyopaque)) i32 else i16;
        // todo: It's possible to store small data inside the pointer rather then alloc
        pub fn retrieve(a: ft) ?*cct {
            const p = guile.scm_foreign_object_ref(a.s, 0);

            return if (p == null) null else @alignCast(@ptrCast(p.?));
        }

        pub fn make(alloct: std.mem.Allocator) !*cct {
            return alloct.create(CType);
        }
    };
}

// todo: remember_upto_here
// todo: Fluids
// todo: Hooks

// todo: type check t
pub fn withContinuationBarrier(captures: anytype, comptime t: type) void {
    const ContinuationBarrierC = struct {
        fn barrier(data: ?*anyopaque) callconv(.C) ?*anyopaque {
            t.barrier(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }
    };

    //todo: check for null on exception and how exception should be handled
    _ = guile.scm_c_with_continuation_barrier(ContinuationBarrierC.barrier, @constCast(@ptrCast(&captures)));
}

// todo: io

//todo type check
pub fn defineModule(name: [:0]const u8, df: anytype) Module {
    const f = struct {
        pub fn cModuleDefine(_: ?*anyopaque) callconv(.C) void {
            df();
        }
    };

    return .{ .s = guile.scm_c_define_module(name, f.cModuleDefine, null) };
}

pub fn newline() void {
    _ = guile.scm_newline(guile.scm_current_output_port());
}

pub fn display(a: anytype) void {
    _ = guile.scm_display(a.s, guile.scm_current_output_port());
}

pub fn newlineErr() void {
    _ = guile.scm_newline(guile.scm_current_error_port());
}

pub fn displayErr(a: anytype) void {
    _ = guile.scm_display(a.s, guile.scm_current_error_port());
}

//todo  ptr type checking
pub fn catchException(key: [:0]const u8, captures: anytype, comptime t: type) void {
    const ExpC = struct {
        fn body(data: ?*anyopaque) callconv(.C) guile.SCM {
            t.body(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }

        // zig fmt: off
        fn handler(data: ?*anyopaque, _key: guile.SCM, args: guile.SCM) callconv(.C) guile.SCM {
            t.handler(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))),
                      Symbol{ .s = _key },
                      Any{ .s = args });

            return guile.SCM_UNDEFINED;
        }
    };

    _ = guile.scm_internal_catch(Symbol.from(key).s,
                                 ExpC.body   , @constCast(@ptrCast(&captures)),
                                 ExpC.handler, @constCast(@ptrCast(&captures)));
            // zig fmt: on
}

pub fn UnionSCM(scmTypes: anytype) type {
    //todo: check for tuple of types of scms
    comptime var uf: [scmTypes.len]std.builtin.Type.UnionField = undefined;
    comptime var ef: [scmTypes.len]std.builtin.Type.EnumField = undefined;

    // check if greater then lower case alphabet
    inline for (scmTypes, 0..) |t, i| {
        //todo: check the types

        uf[i] = std.builtin.Type.UnionField{ .alignment = 0, .name = &[_:0]u8{0x61 + i}, .type = t };
        ef[i] = std.builtin.Type.EnumField{ .name = &[_:0]u8{0x61 + i}, .value = i };

        //todo the type names will be wrong.
    }

    // zig fmt: off
    const ET = @Type(.{
        .Enum = .{
            .tag_type = u8,
            .fields = &ef,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true
    }});

    return @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = ET,
            .fields = &uf,
            .decls = &[_]std.builtin.Type.Declaration{}
    }});
    // zig fmt: on
}

//todo: check for optional type on `a`
pub fn orUndefined(a: anytype) guile.SCM {
    return if (a == null) guile.SCM_UNDEFINED else a.?.s;
}

pub const initThreadForGuile = guile.scm_init_guile;

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
pub const guile = @import("guile");

/// Zig implementation of Guiles bit stuffing rules. libguile/scm.h
pub const internal_workings = @import("internal_workings.zig");

pub const contracts = @import("contracts.zig");
const GZZGType = contracts.GZZGType;
const GZZGTypes = contracts.GZZGTypes;
const GZZGOptionalType = contracts.GZZGOptionalType;

//| boxes -d whirly -a c
//add 20 space indent

//                      .+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.
//                     (                                                     )
//                      ) G u i l e   T y p e :   D e f a u l t   T y p e s (
//                     (                                                     )
//                      "+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"

pub const GuileGCAllocator = struct {
    const Alignment = std.mem.Alignment;

    what: [:0]const u8,
    // todo: consider if it was a single threaded application. could it be worth creating a stack of `whats` that can
    // scoped to give more context?

    pub fn allocator(self: *GuileGCAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(ctx));
        _ = ret_addr;

        switch (alignment.order(.@"8")) {
            .gt, .eq => {},
            .lt => return null, // libguile/scm.h:228
        }

        return @ptrCast(guile.scm_gc_malloc(len, self.what));
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(context));
        _ = alignment;
        _ = ret_addr;

        _ = guile.scm_gc_realloc(memory.ptr, memory.len, new_len, self.what);
        @panic("Resize not implemented");
        //todo: fix and check resize alloc op.
        //return true;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = context;
        _ = memory;
        _ = alignment;
        _ = new_len;
        _ = ret_addr;
        @panic("Unimplemented");
    }

    fn free(context: *anyopaque, buf: []u8, alignment: Alignment, ret_addr: usize) void {
        const self: *GuileGCAllocator = @alignCast(@ptrCast(context));
        _ = alignment;
        _ = ret_addr;

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

pub const Smob   = @import("smob.zig").Smob;
pub const Thread = @import("thread.zig").Thread;
pub const Hook   = @import("hook.zig").Hook;

//
//

pub const Module      = @import("program.zig").Module;
pub const Procedure   = @import("program.zig").Procedure;
pub const ForeignType = struct { s: guile.SCM };

//
//

pub const Stack = @import("vm.zig").Stack;
pub const Frame = @import("vm.zig").Frame;

// zig fmt: on

pub const Any = extern struct {
    pub const UNDEFINED = Any{ .s = guile.SCM_UNDEFINED };
    pub const UNSPECIFIED = Any{ .s = guile.SCM_UNSPECIFIED };
    // todo: consider EOF, EOL,ELISP_NILL?

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

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(guile.SCM));
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

pub fn eqZ(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
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

pub fn UnionSCM(scmTypes: anytype) GZZGTypes(scmTypes, type) {
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

pub fn orUndefined(a: anytype) GZZGOptionalType(@TypeOf(a), guile.SCM) {
    return if (a == null) Any.UNDEFINED.s else a.?.s;
}

pub const initThreadForGuile = guile.scm_init_guile;

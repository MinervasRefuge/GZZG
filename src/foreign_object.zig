// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Symbol = gzzg.Symbol;

//                                      ---------------------
//                                      Foreign Objects §6.20
//                                      ---------------------

pub const ForeignType = struct {
    s: guile.SCM,

    pub const guile_name = "foreign-type";

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

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

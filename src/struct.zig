// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Any       = gzzg.Any;
const Boolean   = gzzg.Boolean;
const Integer   = gzzg.Integer;
const List      = gzzg.List;
const Procedure = gzzg.Procedure;
const String    = gzzg.String;
const Symbol    = gzzg.Symbol;


//                                        -----------------
//                                        Vtables §6.6.18.1
//                                        -----------------

pub const VTable = struct {
    s: guile.SCM,

    pub const guile_name = "vtable";

    pub fn is (a: guile.SCM) Boolean { return guile.scm_struct_vtable_p(a.s); }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }
    pub fn lowerZ(a: VTable) Any { return .{ .s = a.s }; }

    // VTable are Structs (though "specialised")
    pub fn lowerStruct(a: VTable) Struct { return .{ .s = a.s }; }

    // same as make-vtable
    pub fn makeLayout(fields: String) Symbol { return .{ .s = guile.scm_make_struct_layout(fields) }; }

    // not documented
    pub fn make(fields: String, printer: Procedure) VTable {
        return .{ guile.scm_make_vtable(fields.s, printer.s) };
    }
    
    // §6.6.18.3 Vtable Contents
    // scm_vtable_index_layout
    // scm_vtable_index_printer

    pub fn getName(a: VTable) Symbol {
        return .{ .s = guile.scm_struct_vtable_name(a.s) };
    }

    pub fn setName(a: VTable, name: Symbol) void {
        _ = guile.scm_set_struct_vtable_name_x(a.s, name.s);
    }

    const SCMType = enum(u8) {
        protected = 'p',
        unboxed   = 'u',
    };

    const Permission = enum(u8) {
        writable  = 'w',
        read_only = 'r', // should cause a deprecation warning based on docs
        hidden    = 'h', // not in the info doc
    };

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

//                                       ------------------
//                                       Structures §6.6.18
//                                       ------------------

pub const Struct = struct {
    s: guile.SCM,

    pub const guile_name = "struct";

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_struct_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }
    pub fn lowerZ(a: Struct) Any { return .{ .s = a.s }; }

    // https://www.wingolog.org/archives/2020/02/07/lessons-learned-from-guile-the-ancient-spry
    // it's noted that the tail parm is /depreciated/.
    // The docs aren't quite upto date yet?

    pub fn make(vt: VTable, init: List) Struct {
        return .{ .s = guile.scm_make_struct_no_tail(vt.s, init.s) };
    }

    pub fn ref (a: Struct, pos: Integer) Any { return .{ .s = guile.scm_struct_ref(a.s, pos.s) }; }
    pub fn setX(a: Struct, pos: Integer, value: Any) void { _ = guile.scm_struct_set_x(a.s, pos.s, value.s); }

    pub fn refUnboxed (a: Struct, pos: Integer) Any { return .{ .s = guile.scm_struct_ref_unboxed(a.s, pos.s) }; }
    pub fn setUnboxedX(a: Struct, pos: Integer, value: Any) void { _ = guile.scm_struct_set_x_unboxed(a.s, pos.s, value.s); }

    pub fn vtable(a: Struct) VTable { return .{ .s = guile.scm_struct_vtable(a.s) }; }

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

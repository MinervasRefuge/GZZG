// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

//                                         --------------
//                                         Boolean §6.6.1
//                                         --------------

pub const Boolean = struct {
    s: guile.SCM,

    // zig fmt: off
    pub const TRUE : Boolean = .{ .s = guile.SCM_BOOL_T };
    pub const FALSE: Boolean = .{ .s = guile.SCM_BOOL_F };

    //const BooleanTrait = struct {
    pub fn from(b: bool) Boolean { return if (b) TRUE else FALSE; }

    pub fn toZ(a: Boolean) bool { return guile.scm_to_bool(a.s) != 0; }

    pub fn is (a: Boolean) Boolean { return .{ .s = guile.scm_boolean_p(a.s) }; }
    pub fn isZ(a: Boolean) bool    { return guile.scm_is_bool(a.s) != 0; }

    pub fn not(a: Boolean) Boolean { return .{ .s = guile.scm_not(a.s) }; }
    // zig fmt: on
};

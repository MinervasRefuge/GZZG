// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;

//                                         --------------
//                                         Boolean §6.6.1
//                                         --------------

pub const Boolean = struct {
    s: guile.SCM,

    pub const TRUE : Boolean = .{ .s = guile.SCM_BOOL_T };
    pub const FALSE: Boolean = .{ .s = guile.SCM_BOOL_F };

    pub fn from(b: bool) Boolean { return if (b) TRUE else FALSE; }

    pub fn toZ(a: Boolean) bool { return guile.scm_to_bool(a.s) != 0; }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_boolean_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_bool(a) != 0; }

    pub fn lowerZ(a: Boolean) Any { return .{ .s = a.s }; }

    pub fn not(a: Boolean) Boolean { return .{ .s = guile.scm_not(a.s) }; }
};

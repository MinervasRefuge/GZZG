// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;

//                                         --------------
//                                         Vector §6.6.10
//                                         --------------

pub const Vector = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_vector_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_vector(a) != 0; }

    pub fn lowerZ(a: Vector) Any { return .{ .s = a.s }; }
    // zig fmt: on
};

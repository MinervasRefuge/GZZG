// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType = gzzg.contracts.GZZGType;

const Boolean = gzzg.Boolean;

pub const Any = extern struct {
    pub const ELISP_NIL   = Any{ .s = guile.SCM_ELISP_NIL };
    pub const EOF         = Any{ .s = guile.SCM_EOF_VALUE };
    pub const EOL         = Any{ .s = guile.SCM_EOL };
    pub const UNDEFINED   = Any{ .s = guile.SCM_UNDEFINED };
    pub const UNSPECIFIED = Any{ .s = guile.SCM_UNSPECIFIED };

    pub const guile_name = "any";

    s: guile.SCM,

    pub fn is (_: guile.SCM) Boolean { return Boolean.TRUE; } // what about `guile.SCM_UNDEFINED`?
    pub fn isZ(_: guile.SCM) bool    { return true; }

    pub inline fn lowerZ(a: Any) Any { return a; }

    pub fn raiseZ(a: Any, comptime SCMType: type) GZZGType(SCMType, ?SCMType) {
        if (!@hasDecl(SCMType, "isZ"))
            @compileError("Missing `isZ` for type narrowing (`raise`) on " ++ @typeName(SCMType));

        //todo: add child type check

        return if (SCMType.isZ(a.s)) .{ .s = a.s } else null;
    }

    pub inline fn raiseUnsafeZ(a: Any, comptime SCMType: type) GZZGType(SCMType, SCMType) {
        return .{ .s = a.s };
    }

    pub fn isEOF(a: Any) Boolean { return .{ .s = guile.scm_eof_object_p(a.s) }; }
    pub fn isEOFZ(a: Any) bool { return gzzg.eqZ(a, EOF); } // this is identical to the c code.

    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(guile.SCM));
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

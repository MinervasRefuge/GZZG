// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Boolean = gzzg.Boolean;

pub const Any = extern struct {
    pub const UNDEFINED   = Any{ .s = guile.SCM_UNDEFINED };
    pub const UNSPECIFIED = Any{ .s = guile.SCM_UNSPECIFIED };
    // todo: consider EOF, EOL,ELISP_NILL?

    s: guile.SCM,

    pub fn is (_: guile.SCM) Boolean { return Boolean.TRUE; } // what about `guile.SCM_UNDEFINED`?
    pub fn isZ(_: guile.SCM) bool    { return true; }

    pub fn lowerZ(a: Any) Any { return a; }

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

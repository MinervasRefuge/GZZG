// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;
const iw = gzzg.internal_workings;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const Smob = gzzg.Smob;

// zig fmt: off

//                                         --------------
//                                         Thread §6.22.1
//                                         --------------

const Thread = struct {
    s: guile.SCM,

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_thread_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }

    pub fn lowerZ(a: Thread) Any { return .{ .s = a.s }; }
    pub fn lowerSmob(a: Thread) Smob { return .{ .s = a.s }; }

    pub fn current() Thread { return .{ .s = guile.scm_current_thread() }; }

    // todo: have an I know what I'm doing mode?
    pub fn data(a: Thread) *guile.scm_thread {
        return @ptrCast(iw.getSCMCell(iw.gSCMtoIWSCM(a.s), 1));
    }
};

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;

// zig fmt: off

//                                           -----------
//                                           Hook §6.9.6
//                                           -----------

const Hook = struct {
    s: guile.SCM,

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_hook_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }

    pub fn lowerZ(a: Hook) Any { return .{ .s = a.s }; }
};

//#define SCM_HOOKP(x)            SCM_SMOB_PREDICATE (scm_tc16_hook, x)
//#define SCM_HOOK_ARITY(hook)        SCM_SMOB_FLAGS (hook)
//#define SCM_HOOK_PROCEDURES(hook)    SCM_SMOB_OBJECT (hook)
//#define SCM_SET_HOOK_PROCEDURES(hook, procs) SCM_SET_SMOB_OBJECT ((hook), (procs))
//
//#define SCM_VALIDATE_HOOK(pos, a) SCM_MAKE_VALIDATE_MSG (pos, a, HOOKP, "hook")
//
//SCM_API SCM scm_make_hook (SCM n_args);
//SCM_API SCM scm_hook_empty_p (SCM hook);
//SCM_API SCM scm_add_hook_x (SCM hook, SCM thunk, SCM appendp);
//SCM_API SCM scm_remove_hook_x (SCM hook, SCM thunk);
//SCM_API SCM scm_reset_hook_x (SCM hook);
//SCM_API SCM scm_run_hook (SCM hook, SCM args);
//SCM_API void scm_c_run_hook (SCM hook, SCM args);
//SCM_API void scm_c_run_hookn (SCM hook, SCM *argv, size_t nargs);
//SCM_API SCM scm_hook_to_list (SCM hook);

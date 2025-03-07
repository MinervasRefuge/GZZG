// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const bopts = @import("build_options");
const guile = gzzg.guile;
const iw    = gzzg.internal_workings;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;

//                                           ----------
//                                           Smob §6.21
//                                           ----------

const Smob = struct {
    s: guile.SCM,

    pub fn is (a: guile.SCM) Boolean { return Boolean.from(isZ(a)); }
    pub fn isZ(a: guile.SCM) bool    {
        comptime if (bopts.enable_iw_smob) {
            const iww = iw.gSCMtoIWSCM(a);

            return !iw.isImmediate(iww) and iw.getTCFor(iw.TC7, iw.getSCMCell(iww, 0)) == .smob;
        } else {
            return guile.SCM_HAS_TYP7(a, guile.scm_tc7_smob);
        };
    }

    pub fn lowerZ(a: Smob) Any { return .{ .s = a.s }; }

    fn id(a: Smob) usize {
        comptime if (bopts.trust_iw_consts) {
            const iww = iw.gSCMtoIWSCM(a.s);

            return 0x0ff & (iww[0] >> 8);
        } else {
            return guile.SCM_TC2SMOBNUM(a.s[0]);
        };
    }
    
    fn descriptor(a: Smob) guile.scm_smob_descriptor {
        return guile.scm_smobs[a.id()];
    }

    //SCM_SMOBNUM(x)            (SCM_TC2SMOBNUM (SCM_CELL_TYPE (x)))
    //#define SCM_TC2SMOBNUM(x)        (0x0ff & ((x) >> 8))
};

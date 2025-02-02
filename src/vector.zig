// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

//                                         --------------
//                                         Vector §6.6.10
//                                         --------------

pub const Vector = struct { s: guile.SCM };

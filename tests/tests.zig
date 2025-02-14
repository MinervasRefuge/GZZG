// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const refAllDecls = std.testing.refAllDecls;

test {
    refAllDecls(@import("test_altscm.zig"));
    refAllDecls(@import("test_list.zig"));
    //fAllDecls(@import("test_string.zig"));
    refAllDecls(@import("test_vector.zig"));
}

const gzzg = @import("gzzg");
const expect = std.testing.expect;

pub fn gexpect(v: gzzg.Boolean) !void {
    try expect(v.toZ());
}

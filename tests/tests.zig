// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std         = @import("std");
const gzzg        = @import("gzzg");
const refAllDecls = std.testing.refAllDecls;
const expect      = std.testing.expect;

test {
    refAllDecls(@import("test_internal_workings.zig"));
    refAllDecls(@import("test_list.zig"));
    refAllDecls(@import("test_string.zig"));
    refAllDecls(@import("test_vector.zig"));
}

pub fn gexpect(v: gzzg.Boolean) !void {
    try expect(v.toZ());
}

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const guile = gzzg.guile;

const scm = gzzg.altscm;

const gexpect = @import("tests.zig").gexpect;
const expect = std.testing.expect;
const print = std.debug.print;

const Number = gzzg.Number;

test "gzzg immediate integer packing/unpacking" {
    gzzg.initThreadForGuile();

    const fnum_bits = @typeInfo(scm.FixNum).Int.bits;
    const max_range = @divExact(std.math.pow(usize, 2, fnum_bits), 2);

    var n = -@as(isize, @intCast(max_range)); // loop twice the numberVV
    while (n < max_range - 1) : (n += @intCast(@divFloor(max_range, 2025) - 1)) {
        // `alignCast` puts in a check which isn't helpful for testing immediate objects
        @setRuntimeSafety(false);
        const gnum = Number.from(n);
        const s: scm.SCM = @ptrCast(@alignCast(gnum.s));

        // zig fmt: off
        //const fstr = std.fmt.comptimePrint(
        //    "Testing number: {{d}} bits: {{b:0>{d}}}   guile: {{b:0>{d}}}\n",
        //    .{fnum_bits, fnum_bits});
        // zig fmt: on

        //print(fstr, .{ n, n, @intFromPtr(s) });

        try expect(scm.isImmediate(s));
        try expect(scm.isFixNum(s));
        try expect(scm.getFixNum(s) == n);

        const gznum = scm.makeFixNum(@intCast(n));
        try expect(scm.isImmediate(gznum));
        try expect(scm.isFixNum(gznum));
        try expect(gznum == s);
    }
}

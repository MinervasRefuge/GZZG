// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const guile = gzzg.guile;

const expect = std.testing.expect;
const print = std.debug.print;

const Boolean = gzzg.Boolean;
const Number = gzzg.Number;
const Vector = gzzg.Vector;

pub fn gexpect(v: Boolean) !void {
    try expect(v.toZ());
}

test "guile vector iterator" {
    gzzg.initThreadForGuile();

    const gvec: Vector = .{ .s = guile.scm_c_eval_string("#(5 4 3 2 1)") };

    var itr = gvec.iterator();
    defer itr.close();

    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(5)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(4)));
    try gexpect(itr.peek().?.raiseZ(Number).?.equal(Number.from(3)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(3)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(2)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(1)));
    try expect(itr.peek() == null);
    try expect(itr.next() == null);

    itr.reset();

    try gexpect(itr.peek().?.raiseZ(Number).?.equal(Number.from(5)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(5)));
    try gexpect(itr.next().?.raiseZ(Number).?.equal(Number.from(4)));
}

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const guile = gzzg.guile;

const expect = std.testing.expect;
const print = std.debug.print;

const Boolean = gzzg.Boolean;
const Number = gzzg.Number;
const List = gzzg.List;

pub fn gexpect(v: Boolean) !void {
    try expect(v.toZ());
}

test "guile list iterator" {
    gzzg.initThreadForGuile();

    const glist: List = .{ .s = guile.scm_c_eval_string("'(5 4 3 2 1)") };

    var itr = glist.iterator();

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

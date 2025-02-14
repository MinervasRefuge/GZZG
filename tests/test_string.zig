// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const guile = gzzg.guile;

const gexpect = @import("tests.zig").gexpect;
const expect = std.testing.expect;
const print = std.debug.print;

const Char = gzzg.Character;
const Number = gzzg.Number;
const String = gzzg.String;

test "guile string from/to" {
    gzzg.initThreadForGuile();
    var buffer: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    //    const str =
    //        \\You walk past the café, but you don't eat
    //        \\When you've lived too long
    //    ;

    const str = "café";

    const gstr = String.from(str);
    const out = try gstr.toCStr(fba.allocator());

    //gzzg.displayErr(gstr);
    //print(" : {s} : {s}\n{d} : {d} : {d}\n\n", .{ out, str, gstr.lenZ(), out.len, str.len });
    print(".\n in:{X: >2} {s}\nout:{X: >2} {s}\n", .{ str, str, out, out });
    print("gstr len: {d}\n", .{gstr.lenZ()});
    const gf: gzzg.Procedure = .{ .s = guile.scm_c_eval_string("(lambda (a) (map (lambda (b) (number->string (char->integer b) 16)) (string->list a)))") };

    gzzg.displayErr(gstr);
    gzzg.newlineErr();
    gzzg.displayErr(gzzg.call(gf, .{gstr}));

    //    for(out.len)
    try expect(std.mem.eql(u8, str, out));
}

//caf?
//(63 61 66 e9)
//error: 'test_string.test.guile string from/to' failed: .
// in:{ 63, 61, 66, C3, A9 } café
//out:{ 63, 61, 66, 3F, AA } caf?
//gstr len: 4

test "guile string ref" {
    gzzg.initThreadForGuile();

    // zig fmt: off
    const str  = "Hello World!";
    const gstr = String.fromCStr(str);

    try expect(str.len == gstr.lenZ());
    try gexpect(Number.from(str.len).equal(gstr.len()));

    try gexpect(gstr.refZ( 0).equal(Char.fromZ('H')));
    try gexpect(gstr.refZ( 1).equal(Char.fromZ('e')));
    try gexpect(gstr.refZ( 2).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ( 3).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ( 4).equal(Char.fromZ('o')));
    try gexpect(gstr.refZ( 5).equal(Char.fromZ(' ')));
    try gexpect(gstr.refZ( 6).equal(Char.fromZ('W')));
    try gexpect(gstr.refZ( 7).equal(Char.fromZ('o')));
    try gexpect(gstr.refZ( 8).equal(Char.fromZ('r')));
    try gexpect(gstr.refZ( 9).equal(Char.fromZ('l')));
    try gexpect(gstr.refZ(10).equal(Char.fromZ('d')));
    try gexpect(gstr.refZ(11).equal(Char.fromZ('!')));

    try gexpect(gstr.ref(Number.from(4)).equal(Char.fromZ('o')));
    try gexpect(gstr.ref(Number.from(5)).equal(Char.fromZ(' ')));
    try gexpect(gstr.ref(Number.from(6)).equal(Char.fromZ('W')));
    // zig fmt: on
}

test "guile string iter" {
    gzzg.initThreadForGuile();

    const str = "Then we were Ziggy's band";
    const gstr = String.fromCStr(str);

    var itr = gstr.iterator();

    var idx: usize = 0;
    while (itr.next()) |c| : (idx += 1) {
        try expect(c.toZ() == str[idx]);
    }
}

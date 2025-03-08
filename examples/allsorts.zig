// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg");
const guile = gzzg.guile;

pub fn main() !void {
    guile.scm_init_guile();

    const out_port = guile.scm_current_output_port();
    const scmstr = guile.scm_from_utf8_string("Hello World!");
    const scmstr2 = gzzg.String.fromUTF8("And again but different.");

    _ = guile.scm_display(scmstr, out_port);
    _ = guile.scm_newline(out_port);

    //const str_module: *const [*:0]u8 = "guile";
    //const str_fn_display: *const [*:0]u8 = "display";
    const gfn_display = guile.scm_c_public_ref("guile", "display");

    _ = guile.scm_call_1(gfn_display, scmstr2.s);
    _ = guile.scm_newline(out_port);

    const w = std.io.getStdOut().writer();

    try w.print("Would you look at that!\n", .{});
    try w.print("SCM size:{d} => struct(scm) {d}\n", .{ @sizeOf(guile.SCM), @sizeOf(struct { m: guile.SCM }) });

    //    const test_int = GInteger{ .s = 5 };
    //    //const test_flt: gFlt = test_int;
    //    const test_flt = GRational{ .s = 5 };
    //
    //    _ = gSumOld(@as(u32, 5), @as(i16, 5));

    //    try w.print("tint: {d}, tflt: {d}\n", .{ test_int.s, test_flt.s });

    try w.print("\n\nLet's try with scm now!\n", .{});

    const na = gzzg.Number.from(54321);
    const nb = gzzg.Number.from(432.665);

    _ = nb.sum(nb);

    const no = na.sum(nb);

    try w.print("na: " ++ @typeName(@TypeOf(na)) ++ " nb: " ++ @typeName(@TypeOf(nb)) ++ " no: " ++ @typeName(@TypeOf(no)) ++ "\n", .{});

    //try w.print("\n{d} + {d} = native: {d} scm: {d}\n", .{gIntegerToU32(na), gIntegerToU32(nb),
    //                                                      gIntegerToU32(na) + gIntegerToU32(nb),
    //                                                      gIntegerToU32(no)});

    _ = guile.scm_call_1(gfn_display, no.s);
    _ = guile.scm_newline(out_port);
    _ = guile.scm_display(gzzg.Number.from(30).sum(gzzg.Number.from(12)).s, out_port);
    _ = guile.scm_newline(out_port);

    const lst = gzzg.List.init(.{ gzzg.Number.from(5), gzzg.Number.from(1) });

    _ = guile.scm_display(lst.s, out_port);
    _ = guile.scm_newline(out_port);

    _ = guile.scm_display(guile.scm_append_x(gzzg.List.init(.{ lst, gzzg.List.init(.{ gzzg.String.fromUTF8("a"), gzzg.String.fromUTF8("b") }) }).s), out_port);
    _ = guile.scm_newline(out_port);

    _ = guile.scm_display(lst.s, out_port);
    _ = guile.scm_newline(out_port);

    const la = gzzg.List.init(.{ gzzg.Number.from(5), gzzg.Number.from(2) });
    gzzg.display(la);
    gzzg.newline();

    if (gzzg.Number.from(5).divide(gzzg.Number.from(0))) |v| {
        std.debug.print("{}\n", .{v});
    } else |_| {
        std.debug.print("error div zero catched\n", .{});
    }
    gzzg.newline();
    gzzg.display(gzzg.String.fromUTF8("It Worked!\n"));

    const dbz = gzzg.Procedure.define("div-by-zero", divideByZero, "Test of raise exceptions from a zig error", false);

    _ = guile.scm_call_0(dbz.s);
}

fn divideByZero() !gzzg.Number {
    const a = try gzzg.Number.from(10).divide(gzzg.Number.from(0));

    return a.sum(gzzg.Number.from(2));
}

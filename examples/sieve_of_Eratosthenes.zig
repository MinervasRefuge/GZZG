// sieve_of_Eratosthenes.zig : Example of calculating primes in Zig,
// Guile and GZZG.
// Copyright (C) 2025  Abigale Raeck
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg");
const guile = gzzg.guile;

pub fn naiveSieve(alloc: std.mem.Allocator, limit: usize) ![]usize {
    var table = try alloc.alloc(bool, limit);
    var out = std.ArrayList(usize).init(alloc);

    defer alloc.free(table);
    errdefer out.deinit();

    for (2..limit) |i| {
        if (!table[i - 2]) {
            try out.append(i);

            var mark_pos: usize = i;
            while (mark_pos < limit) : (mark_pos += i) {
                table[mark_pos - 2] = true;
            }
        }
    }

    return out.toOwnedSlice();
}

pub fn comptimeSieve(limit: comptime_int) []comptime_int {
    var table = std.mem.zeroes([limit]bool);
    var out: [limit]comptime_int = undefined;
    var out_fill = 0;

    inline for (2..limit) |i| {
        if (!table[i - 2]) {
            out[out_fill] = i;
            out_fill += 1;

            var mark_pos = i;
            while (mark_pos < limit) : (mark_pos += i) {
                table[mark_pos - 2] = true;
            }
        }
    }

    return out[0..out_fill];
}

//pub fn vectorSieve(limit: usize) []usize {
//}

const scmSieve =
    \\(define (sieve limit)
    \\  (define table (make-bitvector limit #f))
    \\  (define out (list))
    \\
    \\  (let lp ((i 2))
    \\    (unless (bitvector-bit-set? table (- i 2))
    \\      (set! out (cons i out))
    \\      (let lp-mark ((mark i))
    \\        (bitvector-set-bit! table (- mark 2))
    \\        (when (<= (+ mark i) limit)
    \\          (lp-mark (+ mark i)))))
    \\    (when (< i limit)
    \\      (lp (1+ i))))
    \\  (reverse out))
    \\
    \\(display "scm sieve 100:\t\t")
    \\(display (sieve 100))
    \\(newline)
;

pub fn gzzgNaiveSieve(limit: gzzg.Number) !gzzg.ListOf(gzzg.Number) {
    var gc = gzzg.GuileGCAllocator{ .what = "sieve" };
    var alloc = gc.allocator();

    const zlimit = limit.toZ(usize);

    var table = try alloc.alloc(bool, zlimit);
    var out = gzzg.ListOf(gzzg.Number).init(.{});

    defer alloc.free(table);

    for (2..zlimit) |i| {
        if (!table[i - 2]) {
            out = out.cons(gzzg.Number.from(i));

            var mark_pos: usize = i;
            while (mark_pos < zlimit) : (mark_pos += i) {
                table[mark_pos - 2] = true;
            }
        }
    }

    return out.reverse();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const out = try naiveSieve(alloc, 100);
    defer alloc.free(out);

    std.debug.print("naïve sieve {d}:\t{d}\n", .{ 100, out });
    std.debug.print("{s}", .{std.fmt.comptimePrint("comptime sieve {d}:\t{d}\n", .{ 100, comptimeSieve(100) })});

    guile.scm_init_guile();
    //_ = gzzg.evalE(scmSieve, null);     //todo fix

    const gSieveFN = gzzg.Procedure.define("gzzg-naïve-sieve", gzzgNaiveSieve, null, false);
    const gSieveOut = gSieveFN.call(.{gzzg.Number.from(100)}).raiseZ(gzzg.List).?;

    std.debug.print("gzzg naïve sieve {d}:\t", .{100});
    gzzg.display(gSieveOut);
    gzzg.newline();
}

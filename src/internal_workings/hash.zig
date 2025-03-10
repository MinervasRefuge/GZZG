// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

//! Hash functions are based on libguile/hash.c
//! which originally was from...
//!  - http://burtleburtle.net/bob/c/lookup3.c
//!    by Bob Jenkins, May 2006, Public Domain.  No warranty.
//!   (https://web.archive.org/web/20250303200530/http://burtleburtle.net/bob/c/lookup3.c)
//!   if it ever goes down.

const std = @import("std");
const Rot = std.math.IntFittingRange(4, 24+1);

inline fn rot(q: u32, r: Rot) u32 {
    return std.math.rotl(u32, q, r);
}

// inline fn mix(a: *u32, b: *u32, c: *u32) void {
//     a.* -%= c.*; a.* ^= rot(c.*,  4); c.* +%= b.*;
//     b.* -%= a.*; b.* ^= rot(a.*,  6); a.* +%= c.*;
//     c.* -%= b.*; c.* ^= rot(b.*,  8); b.* +%= a.*;
//     a.* -%= c.*; a.* ^= rot(c.*, 16); c.* +%= b.*;
//     b.* -%= a.*; b.* ^= rot(a.*, 19); a.* +%= c.*;
//     c.* -%= b.*; c.* ^= rot(b.*,  4); b.* +%= a.*;
// }

// 1    3   1        3       3    2
// a -= c;  a ^= rot(c, 4);  c += b;

// 1 2 3
// a b c
// b c a
// c a b
// a b c
// b c a
// c a b

inline fn mixPart(a: *u32, b: u32, c: *u32, r: Rot) void {
    a.* -%= c.*;
    a.* ^= rot(c.*, r);
    c.* +%= b;
}

inline fn mix(a: *u32, b: *u32, c: *u32) void {
    mixPart(a, b.*, c,  4);
    mixPart(b, c.*, a,  6);
    mixPart(c, a.*, b,  8);
    mixPart(a, b.*, c, 16);
    mixPart(b, c.*, a, 19);
    mixPart(c, a.*, b,  4);
}

// inline fn final(a: *u32, b: *u32, c: *u32) void {
//     c.* ^= b.*; c.* -%= rot(b.*, 14);
//     a.* ^= c.*; a.* -%= rot(c.*, 11);
//     b.* ^= a.*; b.* -%= rot(a.*, 25);
//     c.* ^= b.*; c.* -%= rot(b.*, 16);
//     a.* ^= c.*; a.* -%= rot(c.*,  4);
//     b.* ^= a.*; b.* -%= rot(a.*, 14);
//     c.* ^= b.*; c.* -%= rot(b.*, 24);
// }

// 1    2  1        2
// c ^= b; c -= rot(b,14); \

inline fn finalPart(a: *u32, b: u32, r: Rot) void {
    a.* ^= b;
    a.* -%= rot(b, r);
}

inline fn final(a: *u32, b: *u32, c: *u32) void {
    finalPart(c, b.*, 14);
    finalPart(a, c.*, 11);
    finalPart(b, a.*, 25);
    finalPart(c, b.*, 16);
    finalPart(a, c.*,  4);
    finalPart(b, a.*, 14);
    finalPart(c, b.*, 24);
}

pub fn jenkinsLookup3Hashword2(T: type, k: []const T) usize {
    const state = 0xDEAD_BEEF + @as(u32, @truncate(k.len << 2)) + 47;
    var a: u32 = state;
    var b: u32 = state;
    var c: u32 = state;

    var idx:usize = 0;
    while (idx < k.len -| 3) : (idx += 3) {
        a +%= k[idx];
        b +%= k[idx + 1];
        c +%= k[idx + 2];

        mix(&a, &b, &c);        
    }
    
    fin: switch (k.len -| idx) {
        3 => {
            c +%= k[idx + 2];
            continue :fin 2;
        },
        2 => {
            b +%= k[idx + 1];
            continue :fin 1;
        },
        1 => {
            a +%= k[idx];
            final(&a, &b, &c);
        },
        0 => {},
        else => unreachable
    }

    return switch (@sizeOf(usize)) {
        8 => @as(usize, c) << 32 | b,
        4 => c,
        else => @compileError("Unsuported usize"),
    };
}

//
//
//

test jenkinsLookup3Hashword2 {
    const iw             = @import("../internal_workings.zig");
    const CharacterWidth = iw.string.encoding.CharacterWidth;
    const expect         = std.testing.expectEqual;

    var buffer:[10] u8 = undefined;
    var fba            = std.heap.FixedBufferAllocator.init(&buffer);

    const callJ = struct {
        fn withBufferSlice(bs: CharacterWidth.BufferSlice) usize {
            return switch (bs) {
                .narrow => |n| jenkinsLookup3Hashword2(CharacterWidth.narrow.backingType(), n),
                .wide   => |w| jenkinsLookup3Hashword2(CharacterWidth.wide  .backingType(), w),
            };
        }
    };

    // (number->string (symbol-hash (string->symbol "")) 16)
    try expect(0x37ab6fc7_b7ab6fc7, jenkinsLookup3Hashword2(u8, "") >> 2);
    try expect(0x30f861bd_1bb9c91f, jenkinsLookup3Hashword2(u8, "lat") >> 2);
    try expect(0x1fbcdf55_c7f31822, jenkinsLookup3Hashword2(u8, "Burra") >> 2);
    try expect(0x1006d95a_65872d89, jenkinsLookup3Hashword2(u8, "hippopotomonstrosesquippedaliophobia") >> 2);
    
    const str = try CharacterWidth.encode(fba.allocator(), "qwerty");
    try expect(0x17aeb93a_e1ad4767, callJ.withBufferSlice(str) >> 2);
    
    const str2 = comptime CharacterWidth.wide.encodeComptime("🯰🯱🯲🯳🯴🯵🯶🯷🯸🯹"); // 0123456789
    try expect(0xdf9b85c_b38e14e3, jenkinsLookup3Hashword2(CharacterWidth.wide.backingType(), &str2) >> 2);
}
    

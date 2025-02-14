// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const guile = @import("gzzg.zig").guile;

// Contains a parallel implementation of guile scm bit un/packing C macros
// Based on guilelib/scm.h

// zig fmt: off

pub const SCMBits = usize;
pub const SCM = *align(8) SCMBits; // libguile/scm.h:228

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

comptime {
    // libguile/scm.h:85
    assert(@sizeOf(SCM) >= 4);
    assert(@sizeOf(SCMBits) >= 4);

    assert(@sizeOf(SCMBits) >= @sizeOf(*anyopaque));
    assert(@sizeOf(SCM) >= @sizeOf(*anyopaque));
    //SCMBits must be a power of 2

    assert(@sizeOf(SCMBits) <= @sizeOf(*anyopaque));
    assert(@sizeOf(SCM) <= @sizeOf(*anyopaque));
}

pub fn isImmediate(scm: SCM) bool {
    return @intFromPtr(scm) & 0b110 != 0;
}


// TC => Type Code <n> (stored in the /n/ least significant bits)

pub const TC1 = enum (u1) {
    scm_object,
    invalid
};

pub const TC2 = enum (u2) {
    heap_or_nonint_immediate,
    invalid,
    small_integer,
    invalid2
};

pub const TC3 = enum(u3) {
    cons,      // 0b000: heap obj
    @"struct", // 0b001: struct / class instance
    int1,      // 0b010: small ints - even
    unused,    // 0b011: closure?
    imm24,     // 0b100: used from bools, chars, & special types: TC8
    tc7,       // 0b101: heap types 1: TC7
    int2,      // 0b110: small ints - odd
    tc7_2,     // 0b111: heap types 2: TC7

    comptime {}
};


pub const TC7 = enum(u7) {
    symbol        = 0b0000_101, // 0x05
    variable      = 0b0000_111, // 0x07
    vector        = 0b0001_101, // 0x0d
    wvect         = 0b0001_111, // 0x0f
    string        = 0b0010_101, // 0x15
    number        = 0b0010_111, // 0x17
    hashtable     = 0b0011_101, // 0x1d
    pointer       = 0b0011_111, // 0x1f
    fluid         = 0b0100_101, // 0x25
    stringbuf     = 0b0100_111, // 0x27
    dynamic_state = 0b0101_101, // 0x2d
    frame         = 0b0101_111, // 0x2f
    keyword       = 0b0110_101, // 0x35
    atomic_box    = 0b0110_111, // 0x37
    syntax        = 0b0111_101, // 0x3d
    values        = 0b0111_111, // 0x3f
    program       = 0b1000_101, // 0x45
    vm_cont       = 0b1000_111, // 0x47
    bytevector    = 0b1001_101, // 0x4d
    unused_4f     = 0b1001_111, // 0x4f
    weak_set      = 0b1010_101, // 0x55
    weak_table    = 0b1010_111, // 0x57
    array         = 0b1011_101, // 0x5d
    bitvector     = 0b1011_111, // 0x5f
    unused_65     = 0b1100_101, // 0x65
    unused_67     = 0b1100_111, // 0x67
    unused_6d     = 0b1101_101, // 0x6d
    unused_6f     = 0b1101_111, // 0x6f
    unused_75     = 0b1110_101, // 0x75
    smob          = 0b1110_111, // 0x77
    port          = 0b1111_101, // 0x7d
    unused_7f     = 0b1111_111, // 0x7f
    _,
};

// immediates other than fixnums
pub const TC8  = enum (u8) {
    special_objects = 0b00000_100,
    characters      = 0b00001_100,
    unused1         = 0b00010_100,
    unused2         = 0b00011_100,
    _,
};

// IFLAG  (line 544)
// SCM_MAKIFLAG_BITS

// SCM_BOOL_F
// SCM_BOOL_T
// SCM_ELISP_NIL
// SCM_EOL
// SCM_EOF_VAL
// SCM_UNSPECIFIED
// SCM_UNDEFINED

// zig fmt: off

pub const TC16 = enum (u16) { //tc16 (for tc7==scm_tc7_smob):
    _,
};

pub fn getTCFor(TC: type, scm: SCM) TC {
    const etc = switch (@typeInfo(TC)) {
        .Enum => |e| e,
        else => @compileError("Expected enum"),
    };
        
    return @enumFromInt(@as(etc.tag_type, @truncate(@intFromPtr(scm))));
}

//
//
//

// §7.6.2.21 (rnrs arithmetic fixnums) naming
pub const FixNum = @Type(.{ .Int = .{
    .signedness = .signed,
    .bits = @typeInfo(isize).Int.bits - 2,
} });

// used in internal casting
const UFixNum = @Type(.{ .Int = .{
    .signedness = .unsigned,
    .bits = @typeInfo(usize).Int.bits - 2,
} });

pub fn isFixNum(scm: SCM) bool {
    return getTCFor(TC2, scm) == .small_integer;
}
 
pub fn getFixNum(scm: SCM) FixNum {
    @setRuntimeSafety(false);
    return @bitCast(@as(UFixNum, @intCast(@intFromPtr(scm) >> 2)));
}

pub fn makeFixNum(i: FixNum) SCM {
    // Immediates aren't ptrs and don't have a ptr aligned as expect.
    @setRuntimeSafety(false);
    
    const unum: usize = @intCast(@as(UFixNum, @bitCast(i)));
    const scm = unum << 2 | @intFromEnum(TC2.small_integer);
    
    return @ptrFromInt(scm);
}

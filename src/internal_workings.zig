// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const guile = @import("gzzg.zig").guile;
const bopts = @import("build_options");

// Contains a parallel implementation of guile scm bit un/packing C macros
// Based on libguile/scm.h

pub const SCM     = [*]align(8) usize; // libguile/scm.h:228
pub const SCMBits = usize;

pub fn gSCMtoIWSCM(s: guile.SCM) SCM {
    @setRuntimeSafety(false);

    return @alignCast(@ptrCast(s));
}

pub fn getSCMFrom(int_ptr: usize) SCM {
    @setRuntimeSafety(false);

    return @alignCast(@as(SCM, @ptrFromInt(int_ptr)));
}

pub fn getSCMCell(s: SCM, i: usize) SCM {
    @setRuntimeSafety(false);

    return @alignCast(@as(SCM, @ptrFromInt(s[i])));
}

comptime {
    const assert = std.debug.assert;
    
    assert(@sizeOf(guile.SCM) == @sizeOf(SCM));
    
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

const TC3Raw = enum(u3) {
    cons,      // 0b000: heap obj
    @"struct", // 0b001: struct / class instance
    int1,      // 0b010: small ints - even
    unused,    // 0b011: closure?
    imm24,     // 0b100: used from bools, chars, & special types: TC8
    tc7,       // 0b101: heap types 1: TC7
    int2,      // 0b110: small ints - odd
    tc7_2,     // 0b111: heap types 2: TC7
};

const TC3Guile = enum(u3) {
    cons      = guile.scm_tc3_cons,    
    @"struct" = guile.scm_tc3_struct,
    int1      = guile.scm_tc3_int_1,   
    unused    = guile.scm_tc3_unused,
    imm24     = guile.scm_tc3_imm24,   
    tc7       = guile.scm_tc3_tc7_1,   
    int2      = guile.scm_tc3_int_2,   
    tc7_2     = guile.scm_tc3_tc7_2,   
};

pub const TC3 = if (bopts.trust_iw_consts) TC3Raw else TC3Guile;


const TC7Raw = enum(u7) {
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

const TC7Guile = enum(u7) {
    symbol        =  guile.scm_tc7_symbol,          
    variable      =  guile.scm_tc7_variable,     
    vector        =  guile.scm_tc7_vector,          
    wvect         =  guile.scm_tc7_wvect,           
    string        =  guile.scm_tc7_string,          
    number        =  guile.scm_tc7_number,          
    hashtable     =  guile.scm_tc7_hashtable,       
    pointer       =  guile.scm_tc7_pointer,         
    fluid         =  guile.scm_tc7_fluid,           
    stringbuf     =  guile.scm_tc7_stringbuf,    
    dynamic_state =  guile.scm_tc7_dynamic_state,
    frame         =  guile.scm_tc7_frame,           
    keyword       =  guile.scm_tc7_keyword,         
    atomic_box    =  guile.scm_tc7_atomic_box,      
    syntax        =  guile.scm_tc7_syntax,          
    values        =  guile.scm_tc7_values,          
    program       =  guile.scm_tc7_program,         
    vm_cont       =  guile.scm_tc7_vm_cont,         
    bytevector    =  guile.scm_tc7_bytevector,      
    unused_4f     =  guile.scm_tc7_unused_4f,       
    weak_set      =  guile.scm_tc7_weak_set,        
    weak_table    =  guile.scm_tc7_weak_table,      
    array         =  guile.scm_tc7_array,           
    bitvector     =  guile.scm_tc7_bitvector,       
    unused_65     =  guile.scm_tc7_unused_65,       
    unused_67     =  guile.scm_tc7_unused_67,       
    unused_6d     =  guile.scm_tc7_unused_6d,       
    unused_6f     =  guile.scm_tc7_unused_6f,       
    unused_75     =  guile.scm_tc7_unused_75,       
    smob          =  guile.scm_tc7_smob,            
    port          =  guile.scm_tc7_port,            
    unused_7f     =  guile.scm_tc7_unused_7f,       
    _,    
};

pub const TC7 = if (bopts.trust_iw_consts) TC7Raw else TC7Guile;

// immediates other than fixnums
const TC8Raw  = enum (u8) {
    special_objects = 0b00000_100,
    characters      = 0b00001_100,
    unused1         = 0b00010_100,
    unused2         = 0b00011_100,
    _,
};

const TC8Guile  = enum (u8) {
    special_objects = guile.scm_tc8_flag,
    characters      = guile.scm_tc8_char,
    unused1         = guile.scm_tc8_unused_0, 
    unused2         = guile.scm_tc8_unused_1, 
    _,
};

pub const TC8 = if (bopts.trust_iw_consts) TC8Raw else TC8Guile;

//pub const TC16 = enum (u16) { //tc16 (for tc7==scm_tc7_smob):
//    _,
//};

pub fn getTCFor(TC: type, scm: SCM) TC {
    const etc = switch (@typeInfo(TC)) {
        .@"enum" => |e| e,
        else => @compileError("Expected enum"),
    };
        
    return @enumFromInt(@as(etc.tag_type, @truncate(@intFromPtr(scm))));
}

pub fn unpackPtr(ptr: usize) SCM {
    return @alignCast(@as(SCM, @ptrFromInt(ptr & ~@as(usize, @intCast(0b111)))));
}

pub const GuileClassification = enum {
    array,        
    atomic_box,   
    bit_vector,        
    byte_vector,   
    charator,
    dynamic_state,
    flags,
    fluid,        
    frame,        
    hashtable,    
    keyword,      
    number,
    pointer,      
    port,
    program,      
    smob,         
    special_object,
    string,              
    stringbuf,
    symbol,       
    syntax,       
    values,       
    variable,     
    vector,       
    vm_continuation,      
    weak_set,     
    weak_table,   
    weak_vector,
    
    pub fn classify(a: SCM) GuileClassification {
        if (getTCFor(TC2, a) == .small_integer) return .number;
        
        switch (getTCFor(TC3, a)) {
            .cons => return switch (getTCFor(TC7, getSCMCell(a, 0))) {
                .symbol        => .symbol,     
                .variable      => .variable,
                .vector        => .vector,       
                .wvect         => .weak_vector,        
                .string        => .string,       
                .number        => .number,       
                .hashtable     => .hashtable,    
                .pointer       => .pointer,
                .fluid         => .fluid,
                .stringbuf     => .stringbuf,
                .dynamic_state => .dynamic_state,
                .frame         => .frame,
                .keyword       => .keyword,
                .atomic_box    => .atomic_box,
                .syntax        => .syntax,
                .values        => .values,
                .program       => .program,
                .vm_cont       => .vm_continuation,
                .bytevector    => .byte_vector,
                .weak_set      => .weak_set,
                .weak_table    => .weak_table,
                .array         => .array,
                .bitvector     => .bit_vector,
                .smob          => .smob,
                .port          => .port,
                else => @panic("Unknown heap type")
            },      
            .@"struct" => @panic("Shouldn't exist"), 
            // int1,      
            .unused => @panic("Shouldn't exist"),     
            .imm24 => {
                switch (getTCFor(TC8, a)) {
                    .special_objects => return .special_object,
                    .characters => return .character,
                    else => @panic("Shouldn't Exist")
                }
            },
            // tc7,       
            // int2,      
            // tc7_2,
            else => unreachable
        }
    }
};

//
//
//

// §7.6.2.21 (rnrs arithmetic fixnums) naming
pub const FixNum = @Type(.{ .int = .{
    .signedness = .signed,
    .bits = @typeInfo(isize).int.bits - 2,
} });

// used in internal casting
const UFixNum = @Type(.{ .int = .{
    .signedness = .unsigned,
    .bits = @typeInfo(usize).int.bits - 2,
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


//
//
//

pub fn assertTagSize(tag: type) void {
    if (@sizeOf(tag) != @sizeOf(SCMBits) or @bitSizeOf(tag) != @bitSizeOf(SCMBits)) {
        @compileError("Tag isn't a valid size");
    }
}


/// size in bits
pub fn Padding(size: comptime_int) type {
    const T = std.builtin.Type;    
    
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.meta.Int(.unsigned, size),
            .fields = &[_]T.EnumField{.{.name = "nil", .value = 0}},
            .decls = &[_]T.Declaration{},
            .is_exhaustive = true,
        }
    });
}


pub const hash        = @import("internal_workings/hash.zig");
pub const string      = @import("internal_workings/string.zig");
pub const byte_vector = @import("internal_workings/byte_vector.zig");

test {
    @import("std").testing.refAllDecls(@This());
}


// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Boolean = gzzg.Boolean;
const Number = gzzg.Number;
const Symbol = gzzg.Symbol;

//                                       -------------------
//                                       Byte Vector §6.6.12
//                                       -------------------

pub const ByteVector = struct {
    s: guile.SCM,

    const BIG: Symbol = .{ .s = guile.scm_endianness_big };
    const LITTLE: Symbol = .{ .s = guile.scm_endianness_little };

    pub fn from(data: []u8) ByteVector {
        const bv = init(data.len);

        @memcpy(bv.contents(u8), data);

        return bv;
    }

    pub fn fromI8(data: []i8) ByteVector {
        const bv = init(data.len);

        @memcpy(bv.contents(i8), data);

        return bv;
    }

    // bytevector->u8-list bv
    // u8-list->bytevector lst
    // bytevector->uint-list
    // bytevector->sint-list
    // uint-list->bytevector
    // sint-list->bytevector

    // §6.6.12.6 Interpreting Bytevector Contents as Unicode Strings
    // string-utf8-length
    // string->utf8
    // string->utf16
    // string->utt32
    // utf8->string
    // utf16->string
    // utf32->string

    // zig fmt: off
    pub fn is(a: ByteVector) Boolean { return .{ .s = guile.scm_bytevector_p(a.s) }; }
    pub fn isZ(a: ByteVector) bool { return guile.scm_is_bytevector(a.s) != 0; }

    pub fn init(length: usize) ByteVector {
        return .{ .s = guile.scm_c_make_bytevector(length) };
    }

    pub fn nativeEndianness() Symbol { return .{ .s = guile.scm_native_endianness() }; }
    
    pub fn len(a: ByteVector) Number { return .{ .s = guile.scm_bytevector_length(a.s)}; }
    //pub fn lenZ(a: ByteVector) usize { return guile.scm_c_bytevector_length(a.s); }
    pub fn lenZ(a: ByteVector) usize { return guile.SCM_BYTEVECTOR_LENGTH(a.s); }
    
    pub fn equal(a: ByteVector, b: ByteVector) Boolean { return .{ .s = guile.scm_bytevector_eq_p(a.s, b.s) }; }

    pub fn copy(a: ByteVector) ByteVector { return .{ .s = guile.scm_bytevector_copy(a.s) }; }
    pub fn copyX(src: ByteVector, src_start: Number, dest: ByteVector, dest_start: Number, length: Number) void
        { _ = guile.scm_bytevector_copy_x(src.s, src_start.s, dest.s, dest_start.s, length.s); }

    pub fn contents(a: ByteVector, t: type) []t {
        switch (t) {
            u8, i8 => .{ .ptr = @as([*c]t, guile.SCM_BYTEVECTOR_CONTENTS(a.s)), .len = lenZ(a.s)},
            else => @compileError("Expected u8 or i8 for bytevector contents type")
        }
    }

    // §6.6.12.3  Interpreting Bytevector Contents as Integers
    // todo: exception handeling?
    pub fn u8RefE (a: ByteVector, index: Number) Number
        { return .{ .s = guile.scm_bytevector_u8_ref (a.s, index.s) }; }
    pub fn s8RefE (a: ByteVector, index: Number) Number
        { return .{ .s = guile.scm_bytevector_s8_ref (a.s, index.s) }; }
    
    pub fn u16RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_u16_ref(a.s, index.s, endianness.s) }; }
    pub fn s16RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_s16_ref(a.s, index.s, endianness.s) }; }
    
    pub fn u32RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_u32_ref(a.s, index.s, endianness.s) }; }
    pub fn s32RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_s32_ref(a.s, index.s, endianness.s) }; }
    
    pub fn u64RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_u64_ref(a.s, index.s, endianness.s) }; }
    pub fn s64RefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_s64_ref(a.s, index.s, endianness.s) }; }


    pub fn u8SetEX(a: ByteVector, index:Number, value: Number) void
        { _ = guile.scm_bytevector_u8_set_x(a.s, index.s, value.s); }
    pub fn s8SetEX(a: ByteVector, index:Number, value: Number) void
        { _ = guile.scm_bytevector_s8_set_x(a.s, index.s, value.s); }

    pub fn u16SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_u16_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s16SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_s16_set_x(a.s, index.s, value.s, endianness.s); }

    pub fn u32SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_u32_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s32SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_s32_set_x(a.s, index.s, value.s, endianness.s); }

    pub fn u64SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_u64_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s64SetEX(a: ByteVector, index:Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_s64_set_x(a.s, index.s, value.s, endianness.s); }

    //todo: Native?

    // §6.6.12.5 Interpreting Bytevector Contents as Floating Point Numbers
    pub fn ieeeSingleRefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_ieee_single_ref(a.s, index.s, endianness.s) }; }
    pub fn ieeeDoubleRefE(a: ByteVector, index: Number, endianness: Symbol) Number
        { return .{ .s = guile.scm_bytevector_ieee_double_ref(a.s, index.s, endianness.s) }; }

    pub fn ieeeSingleSetEX(a: ByteVector, index: Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_ieee_single_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn ieeeDoubleSetEX(a: ByteVector, index: Number, value: Number, endianness: Symbol) void
        { _ = guile.scm_bytevector_ieee_double_set_x(a.s, index.s, value.s, endianness.s); }

    //todo: Native?

    // zig fmt: on
};

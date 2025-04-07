// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Integer = gzzg.Integer;
const Symbol  = gzzg.Symbol;

//                                       -------------------
//                                       Byte Vector §6.6.12
//                                       -------------------

pub const ByteVector = extern struct {
    s: guile.SCM,

    pub const guile_name = "byte-vector";
    pub const BIG: Symbol = .{ .s = guile.scm_endianness_big };
    pub const LITTLE: Symbol = .{ .s = guile.scm_endianness_little };

    pub fn from(data: []const u8) ByteVector {
        const bv = init(data.len);

        @memcpy(bv.contents(u8), data);

        return bv;
    }

    pub fn fromI8(data: []const i8) ByteVector {
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

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_bytevector_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_bytevector(a) != 0; }

    pub fn lowerZ(a: ByteVector) Any { return .{ .s = a.s }; }

    pub fn init(length: usize) ByteVector { return .{ .s = guile.scm_c_make_bytevector(length) }; }

    pub fn nativeEndianness() Symbol { return .{ .s = guile.scm_native_endianness() }; }
    
    pub fn len(a: ByteVector) Integer { return .{ .s = guile.scm_bytevector_length(a.s)}; }
    //pub fn lenZ(a: ByteVector) usize { return guile.scm_c_bytevector_length(a.s); }
    pub fn lenZ(a: ByteVector) usize { return a.contents(u8).len; }
    
    pub fn equal(a: ByteVector, b: ByteVector) Boolean { return .{ .s = guile.scm_bytevector_eq_p(a.s, b.s) }; }

    pub fn copy(a: ByteVector) ByteVector { return .{ .s = guile.scm_bytevector_copy(a.s) }; }
    pub fn copyX(src: ByteVector, src_start: Integer, dest: ByteVector, dest_start: Integer, length: Integer) void
        { _ = guile.scm_bytevector_copy_x(src.s, src_start.s, dest.s, dest_start.s, length.s); }

    pub fn contents(a: ByteVector, comptime C: type) []C {
        // todo: gate behind options

        const iw = gzzg.internal_workings;
        const layout: *align(8) iw.byte_vector.Layout = @alignCast(@ptrCast(a.s));
        
        switch (C) {
            u8 => return layout.getContentsU8(),
            else => @compileError("Expected u8 for bytevector contents type")
        }
        
        //switch (C) {
        //    u8, i8 => .{ .ptr = @as([*c]C, guile.SCM_BYTEVECTOR_CONTENTS(a.s)), .len = lenZ(a.s)},
        //    else => @compileError("Expected u8 or i8 for bytevector contents type")
        //}
    }

    // §6.6.12.3  Interpreting Bytevector Contents as Integers
    pub fn u8Ref (a: ByteVector, index: Integer) Integer
        { return .{ .s = guile.scm_bytevector_u8_ref (a.s, index.s) }; }
    pub fn s8Ref (a: ByteVector, index: Integer) Integer
        { return .{ .s = guile.scm_bytevector_s8_ref (a.s, index.s) }; }
    
    pub fn u16Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_u16_ref(a.s, index.s, endianness.s) }; }
    pub fn s16Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_s16_ref(a.s, index.s, endianness.s) }; }
    
    pub fn u32Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_u32_ref(a.s, index.s, endianness.s) }; }
    pub fn s32Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_s32_ref(a.s, index.s, endianness.s) }; }
    
    pub fn u64Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_u64_ref(a.s, index.s, endianness.s) }; }
    pub fn s64Ref(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_s64_ref(a.s, index.s, endianness.s) }; }


    pub fn u8SetX(a: ByteVector, index:Integer, value: Integer) void
        { _ = guile.scm_bytevector_u8_set_x(a.s, index.s, value.s); }
    pub fn s8SetX(a: ByteVector, index:Integer, value: Integer) void
        { _ = guile.scm_bytevector_s8_set_x(a.s, index.s, value.s); }

    pub fn u16SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_u16_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s16SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_s16_set_x(a.s, index.s, value.s, endianness.s); }

    pub fn u32SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_u32_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s32SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_s32_set_x(a.s, index.s, value.s, endianness.s); }

    pub fn u64SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_u64_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn s64SetX(a: ByteVector, index:Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_s64_set_x(a.s, index.s, value.s, endianness.s); }

    //todo: Native?

    // §6.6.12.5 Interpreting Bytevector Contents as Floating Point Integers
    pub fn ieeeSingleRef(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_ieee_single_ref(a.s, index.s, endianness.s) }; }
    pub fn ieeeDoubleRef(a: ByteVector, index: Integer, endianness: Symbol) Integer
        { return .{ .s = guile.scm_bytevector_ieee_double_ref(a.s, index.s, endianness.s) }; }

    pub fn ieeeSingleSetX(a: ByteVector, index: Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_ieee_single_set_x(a.s, index.s, value.s, endianness.s); }
    pub fn ieeeDoubleSetX(a: ByteVector, index: Integer, value: Integer, endianness: Symbol) void
        { _ = guile.scm_bytevector_ieee_double_set_x(a.s, index.s, value.s, endianness.s); }

    //todo: Native?

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

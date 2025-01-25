// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

pub const guile = @cImport({
    @cInclude("libguile.h");
});

//pub fn sum(a: anytype, b: anytype) NumericalTowerCascade(.{ @TypeOf(a), @TypeOf(b) }) {
//    return .{ .s = guile.scm_sum(a.s, b.s) };
//}
//
//pub fn sub(a: anytype, b: anytype) NumericalTowerCascade(.{ @TypeOf(a), @TypeOf(b) }) {
//    return .{ .s = guile.scm_sub(a.s, b.s) };
//}
//
//const NumberTrait = struct {
//    pub fn sum(self: @This(), other: anytype) NumericalTowerCascadeWithPrimitive(.{ @This(), @TypeOf(other) }) {
//        const o = if (comptime numericalTowerP(@TypeOf(other)) == null) numberToSCM(other) else other;
//
//        return sum(self, o);
//    }
//
//    pub fn sub(self: @This(), other: anytype) NumericalTowerCascadeWithPrimitive(.{ @This(), @TypeOf(other) }) {
//        const o = if (comptime numericalTowerP(@TypeOf(other)) == null) numberToSCM(other) else other;
//
//        return sub(self, o);
//    }
//};
//
//// szig fmt: off
//
//pub const GInteger =  struct { s: guile.SCM, pub usingnamespace NumberTrait; };
//pub const GRational = struct { s: guile.SCM, pub usingnamespace NumberTrait; };
//pub const GReal     = struct { s: guile.SCM, pub usingnamespace NumberTrait; };
//pub const GComplex  = struct { s: guile.SCM, pub usingnamespace NumberTrait; };
//
//const numerical_tower = [_]type{ GInteger, GRational, GReal, GComplex };
//
//pub fn numericalTowerP(comptime t: type) ?usize {
//    return std.mem.indexOf(type, &numerical_tower, &[_]type{t});
//}
//
//pub fn gIsNumberP(n: anytype) bool {
//    return guile.scm_is_number(n.s);
//}
//
////pub fn numberToSCM(n: anytype)
//
//pub fn u32ToGInteger(n: u32) GInteger {
//    return .{ .s = guile.scm_from_uint32(n) };
//}
//pub fn gIntegerToU32(scm: GInteger) u32 {
//    return guile.scm_to_uint32(scm.s);
//}
//
//pub fn IntoNumericalTower(comptime t: type) type {
//    return switch (@typeInfo(t)) {
//        .Int  , .ComptimeInt   => GInteger,
//        .Float, .ComptimeFloat => GReal,
//        else => @compileError("Type: " ++ @typeName(t) ++ " is not convertable to part of the numerical tower"),
//    };
//}
//
//pub fn NumericalTowerCascade(comptime nts: anytype) type {
//    var rt = 0;
//
//    inline for (nts) |t| {
//        const idx = numericalTowerP(t);
//
//        if (idx == null) @compileError("Type: " ++ @typeName(t) ++ " is not part of the numerical tower");
//
//        rt = @max(rt, idx.?);
//    }
//
//    return numerical_tower[rt];
//}
//
//pub fn NumericalTowerCascadeWithPrimitive(comptime nts: anytype) type {
//    var rt = 0;
//
//    inline for (nts) |t| {
//        var idx = numericalTowerP(t);
//
//        if (idx == null) idx = numericalTowerP(IntoNumericalTower(t));
//
//        rt = @max(rt, idx.?);
//    }
//
//    return numerical_tower[rt];
//}
//
//pub fn numberToSCM(n: anytype) IntoNumericalTower(@TypeOf(n)) {
//    const scm = switch (@typeInfo(@TypeOf(n))) {
//        .ComptimeInt => guile.scm_from_size_t(n),
//        .Int => |i| switch (i.bits) {
//            8 => switch (i.signedness) {
//                .signed   => guile.scm_from_int8(n),
//                .unsigned => guile.scm_from_uint8(n),
//            },
//            16 => switch (i.signedness) {
//                .signed   => guile.scm_from_int16(n),
//                .unsigned => guile.scm_from_uint16(n),
//            },
//            32 => switch (i.signedness) {
//                .signed   => guile.scm_from_int32(n),
//                .unsigned => guile.scm_from_uint32(n),
//            },
//            64 => switch (i.signedness) {
//                .signed   => guile.scm_from_int64(n),
//                .unsigned => guile.scm_from_uint64(n),
//            },
//            else => @compileError("Type: " ++ @typeName(n) ++ " doesn't have a conversion to scm"),
//        },
//        .ComptimeFloat => guile.scm_from_double(n),
//        .Float         => guile.scm_from_double(@as(f64, n)),
//        else => @compileError("Type: " ++ @typeName(@TypeOf(n)) ++ " is not part of the numerical tower"),
//    };
//
//    return .{ .s = scm };
//}

//pub fn numberToSCM(n: anytype) NumericalTower(@TypeOf(n)) {
//    return switch (@typeInfo(@TypeOf(n))) {
//        .ComptimeInt => .{ .s = guile.scm_from_size_t(n) },
//        .Int => |i| switch (i.bits) {
//            8 => |s| switch (s.signedness) { .signed => .{ .s = guile.scm_from_int8(n) }, .unsigned => .{ .s = guile.scm_from_uint8(n)}},
//            16 => .{ .s = if (i.signedness == .signed) guile.scm_from_int16(n) else guile.scm_from_uint16(n)},
//            32 => .{ .s = if (i.signedness == .signed) guile.scm_from_int32(n) else guile.scm_from_uint32(n)},
//            64 => .{ .s = if (i.signedness == .signed) guile.scm_from_int64(n) else guile.scm_from_uint64(n)},
//            else => @compileError("Type: " ++ @typeName(n) ++ " doesn't have a conversion to scm")
//        },
//        .ComptimeFloat => .{ .s = guile.scm_from_double(n)},
//        .Float => .{ .s = guile.scm_from_double(@as(f64, n))},
//        else => @compileError("Type: " ++ @typeName(@TypeOf(n)) ++ " is not part of the numerical tower")
//    };
//}

//pub fn gSum(comptime T: type, comptime Q: type, comptime Z: type, a: T, b: Q) Z {}

//pub fn gSum(comptime T: type, a: anytype, b: anytype) T {
//    switch (@typeInfo(@TypeOf(a))) {
//        .Int => {
//            return a + @as(@TypeOf(a), @intCast(b));
//       },
//        else => {
//            @compileError("No gSum for '" ++ @typeName(@TypeOf(a)) ++ "' & '" ++ @typeName(@TypeOf(b)) ++ "'");
//        },
//    }
//}

//pub fn gSumOld(a: anytype, b: anytype) u32 {
//    switch (@typeInfo(@TypeOf(a))) {
//        .Int => {
//            return a + @as(@TypeOf(a), @intCast(b));
//        },
//        else => {
//            @compileError("No gSum for '" ++ @typeName(@TypeOf(a)) ++ "' & '" ++ @typeName(@TypeOf(b)) ++ "'");
//        },
//    }
//}

//| boxes -d whirly -a c
//add 20 space indent

//                      .+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.
//                     (                                                     )
//                      ) G u i l e   T y p e :   D e f a u l t   T y p e s (
//                     (                                                     )
//                      "+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"

//todo: consider naming allocations (since it's possible)
pub const GuileGCAllocator = struct {
    pub fn allocator(self: *GuileGCAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    // fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8
    fn alloc(_: *anyopaque, n: usize, _: u8, _: usize) ?[*]u8 {
        return @ptrCast(guile.scm_gc_malloc(n, ""));
    }

    // fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool
    fn resize(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
        _ = guile.scm_gc_realloc(buf.ptr, buf.len, new_len, "");
        @trap();
        //todo: fix and check resize alloc op.
        //return true;
    }

    // fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void
    fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
        guile.scm_gc_free(buf.ptr, buf.len, "");
    }
};

pub fn SCMWrapper(comptime ns: ?type) type {
    if (ns == null) {
        return struct { s: guile.SCM };
    } else {
        return struct {
            s: guile.SCM,

            pub usingnamespace ns.?;
        };
    }
}

// §6.6 Data Types
// using direct structs as (guix) zig-zls@0.13.0 doesn't seem to handle `usingnamespace` correctly
// zig fmt: off
pub const Any        = SCMWrapper(null);

// pub const Boolean    = SCMWrapper(BooleanTrait);
// pub const Number     = SCMWrapper(NumberTrait);
pub const Character  = SCMWrapper(null);
// Character Sets
// pub const String     = SCMWrapper(StringTrait);
//pub const Symbol     = SCMWrapper(SymbolTrait);
pub const Keyword    = SCMWrapper(null);
// pub const Pair       = SCMWrapper(PairTrait);
// pub const List       = SCMWrapper(ListTrait);
pub const Vector     = SCMWrapper(null);
// Bit Vectors
//pub const ByteVector = SCMWrapper(ByteVectorTrait);
//Arrays
//VLists
//Records
//Structures
//Association Lists
//VHashs
pub const HashTable = SCMWrapper(null);

//
//

pub const Module      = SCMWrapper(null);
pub const Procedure   = SCMWrapper(null);
pub const ForeignType = SCMWrapper(null);

// zig fmt: on

//                      .+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.
//                     (                                     )
//                      )G u i l e   T y p e :   T r a i t s(
//                     (                                     )
//                      "+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"

// `to` implies conversion
// `as` implies change
// `from` is the reverse of `to` AToB <=> BFromA

// use `from` as a constructor for the guile type
// append `Z` if function returns zig values.
// append `X` for mutation functions (more-so based on scm function naming)
// append `E` if a known exception can be raised but isn't capture by the function
// CONST => from => to => is => other

//                                         --------------
//                                         Boolean §6.6.1
//                                         --------------

pub const Boolean = struct {
    s: guile.SCM,

    //const BooleanTrait = struct {
    pub fn from(b: bool) Boolean {
        return .{ .s = if (b) guile.SCM_BOOL_T else guile.SCM_BOOL_F };
    }

    pub fn toZ(a: Boolean) bool {
        return guile.scm_to_bool(a.s) != 0;
    }

    pub fn is(a: Boolean) Boolean {
        return .{ .s = guile.scm_boolean_p(a.s) };
    }

    pub fn isZ(a: Boolean) bool {
        return guile.scm_is_bool(a.s) != 0;
    }
};

//                                          -------------
//                                          Number §6.6.2
//                                          -------------

pub const Number = struct {
    s: guile.SCM,

    //const NumberTrait = struct { //todo: is it worth swtching on bit ranges or only standard bit sizes?
    // zig fmt: off
    pub fn from(n: anytype) Number {
        const scm = switch (@typeInfo(@TypeOf(n))) {
            .ComptimeInt => guile.scm_from_size_t(n),
            .Int => |i| switch (i.bits) {
                1...8 => switch (i.signedness) {
                    .signed   => guile.scm_from_int8 (@intCast(n)),
                    .unsigned => guile.scm_from_uint8(@intCast(n)),
                },
                9...16 => switch (i.signedness) {
                    .signed   => guile.scm_from_int16 (@intCast(n)),
                    .unsigned => guile.scm_from_uint16(@intCast(n)),
                },
                17...32 => switch (i.signedness) {
                    .signed   => guile.scm_from_int32 (@intCast(n)),
                    .unsigned => guile.scm_from_uint32(@intCast(n)),
                },
                33...64 => switch (i.signedness) {
                    .signed   => guile.scm_from_int64 (@intCast(n)),
                    .unsigned => guile.scm_from_uint64(@intCast(n)),
                },
                else => @compileError("IntType: " ++ @typeName(n) ++ " doesn't have a conversion"),
            },
            .ComptimeFloat => guile.scm_from_double(n),
            .Float         => guile.scm_from_double(@as(f64, n)),
            else => @compileError("Type: " ++ @typeName(@TypeOf(n)) ++ " is not part of the numerical tower"),
        };

        return .{ .s = scm };
    }

    //todo: error or optional if outside unit size?
    pub fn toZ(a: Number, comptime t: type) t {
        return switch (@typeInfo(t)) {
            .Int => |i| switch (i.bits) {
                8 => switch (i.signedness) {
                    .signed   => guile.scm_to_int8 (a.s),
                    .unsigned => guile.scm_to_uint8(a.s),
                },
                16 => switch (i.signedness) {
                    .signed   => guile.scm_to_int16 (a.s),
                    .unsigned => guile.scm_to_uint16(a.s),
                },
                32 => switch (i.signedness) {
                    .signed   => guile.scm_to_int32 (a.s),
                    .unsigned => guile.scm_to_uint32(a.s),
                },
                64 => switch (i.signedness) {
                    .signed   => guile.scm_to_int64 (a.s),
                    .unsigned => guile.scm_to_uint64(a.s),
                },
                else => @compileError("IntType: " ++ @typeName(t) ++ " doesn't have a conversion."), //todo fix
            },
            .Float => guile.scm_to_double(a.s),
            else => @compileError("Type: " ++ @typeName(@TypeOf(t)) ++ " is not a number"), // todo fix
        };
    }

    pub fn toString(a: Number, radix: ?Number) String {
        const r = if (radix != null) radix.?.s else guile.SCM_UNDEFINED;
        
        return .{ .s = guile.scm_number_to_string(a.s, r) };
    }

    pub fn is(a: Number) Boolean { return .{ .s = guile.scm_number_p (a.s) }; }
    pub fn isZ(a: Number) bool   { return .{ .s = guile.scm_is_number(a.s) }; }

    pub fn isExactInteger(a: Number) Boolean { return .{ .s = guile.scm_exact_integer_p(a.s) }; }
    pub fn isInteger     (a: Number) Boolean { return .{ .s = guile.scm_integer_p      (a.s) }; }
    pub fn isRational    (a: Number) Boolean { return .{ .s = guile.scm_rational_p     (a.s) }; }
    pub fn isReal        (a: Number) Boolean { return .{ .s = guile.scm_real_p         (a.s) }; }
    pub fn isComplex     (a: Number) Boolean { return .{ .s = guile.scm_complex_p      (a.s) }; }
    pub fn isExact       (a: Number) Boolean { return .{ .s = guile.scm_exact_p        (a.s) }; }
    pub fn isInexact     (a: Number) Boolean { return .{ .s = guile.scm_inexact_p      (a.s) }; }
    
    pub fn isExactIntegerZ(a: Number) bool { return guile.scm_is_exact_integer(a.s) != 0; }
    pub fn isIntegerZ     (a: Number) bool { return guile.scm_is_integer      (a.s) != 0; }
    pub fn isRationalZ    (a: Number) bool { return guile.scm_is_rational     (a.s) != 0; }
    pub fn isRealZ        (a: Number) bool { return guile.scm_is_real         (a.s) != 0; }
    pub fn isComplexZ     (a: Number) bool { return guile.scm_is_complex      (a.s) != 0; }
    pub fn isExactZ       (a: Number) bool { return guile.scm_is_exact        (a.s) != 0; }
    pub fn isInexactZ     (a: Number) bool { return guile.scm_is_inexact      (a.s) != 0; }

    //
    //

    pub fn exactToInexact(a: Number) Number { return .{ .s = guile.scm_exact_to_inexact(a.s) }; }
    pub fn inexactToExact(a: Number) Number { return .{ .s = guile.scm_inexact_to_exact(a.s) }; }

    //
    //

    // zig fmt: on

    pub fn sum(a: Number, b: ?Number) Number {
        const as = a.s;
        const bs = if (b != null) b.?.s else guile.SCM_UNDEFINED;

        return .{ .s = guile.scm_sum(as, bs) };
    }

    pub fn difference(a: Number, b: ?Number) Number {
        const as = a.s;
        const bs = if (b != null) b.s else guile.SCM_UNDEFINED;

        return .{ .s = guile.scm_difference(as, bs) };
    }

    pub fn product(a: Number, b: ?Number) Number {
        const as = a.s;
        const bs = if (b != null) b.?.s else guile.SCM_UNDEFINED;

        return .{ .s = guile.scm_product(as, bs) };
    }

    pub fn divide(a: Number, b: ?Number) !Number {
        const as = a.s;
        const bs = if (b != null) b.?.s else guile.SCM_UNDEFINED;

        var out: error{numericalOverflow}!Number = undefined;

        catchException("numerical-overflow", .{ as, bs, &out }, struct {
            pub fn body(data: anytype) void {
                data[2].* = .{ .s = guile.scm_divide(data[0], data[1]) };
            }

            pub fn handler(data: anytype, _: Symbol, _: Any) void {
                data[2].* = error.numericalOverflow;
            }
        });

        return out;
    }

    pub fn divideE(a: Number, b: ?Number) Number {
        const as = a.s;
        const bs = if (b != null) b.?.s else guile.SCM_UNDEFINED;

        return .{ .s = guile.scm_divide(as, bs) };
    }

    pub fn onePlus(a: Number) Number {
        return .{ .s = guile.scm_oneplus(a.s) };
    }

    pub fn oneMinus(a: Number) Number {
        return .{ .s = guile.scm_oneminus(a.s) };
    }
};

//                                        ----------------
//                                        Character §6.6.3
//                                        ----------------

//                                      --------------------
//                                      Character Set §6.6.4
//                                      --------------------

//                                          -------------
//                                          String §6.6.5
//                                          -------------

//todo: check string encoding perticulars.
pub const String = struct {
    s: guile.SCM,

    pub fn from(s: []const u8) String {
        return .{ .s = guile.scm_from_utf8_stringn(s.ptr, s.len) };
    }

    pub fn fromCStr(s: [:0]const u8) String {
        return .{ .s = guile.scm_from_utf8_string(s.ptr) };
    }

    pub fn toCStr(a: String, allocator: std.mem.Allocator) ![:0]u8 {
        const l = a.lenZ();
        const buf = try allocator.alloc(u8, l + 1);
        const written = guile.scm_to_locale_stringbuf(a.s, buf.ptr, l);
        std.debug.assert(l == written);

        buf[l] = 0;
        return buf[0..l :0];
    }

    pub fn toZ(a: String, allocator: std.mem.Allocator) ![]u8 {
        const l = a.lenZ();
        const buf = try allocator.alloc(u8, l + 1); //todo +1?
        const written = guile.scm_to_locale_stringbuf(a.s, buf.ptr, l);
        std.debug.assert(l == written);

        return buf;
    }

    pub fn is(a: String) Boolean {
        return .{ .s = guile.scm_string_p(a.s) };
    }

    pub fn isZ(a: String) bool {
        return guile.scm_is_string(a.s) != 0;
    }

    pub fn len(a: String) Number {
        return .{ .s = guile.scm_string_length(a.s) };
    }

    pub fn lenZ(a: String) usize {
        return guile.scm_c_string_length(a.s);
    }
};

//                                          -------------
//                                          Symbol §6.6.6
//                                          -------------

// const SymbolTrait = struct {
pub const Symbol = struct {
    s: guile.SCM,

    pub fn from(s: []const u8) Symbol {
        return .{ .s = guile.scm_from_utf8_symboln(s.ptr, s.len) };
    }

    pub fn fromCStr(s: [:0]const u8) Symbol {
        return .{ .s = guile.scm_from_utf8_symbol(s.ptr) };
    }
};

//                                         --------------
//                                         Keyword §6.6.7
//                                         --------------

//                                           -----------
//                                           Pair §6.6.8
//                                           -----------

//const PairTrait = struct {
pub const Pair = struct {
    s: guile.SCM,

    pub fn from(x: anytype, y: anytype) Pair { //todo: typecheck
        return .{ .s = guile.scm_cons(x.s, y.s) };
    }

    pub fn isPair(a: Pair) Boolean {
        return .{ .s = guile.scm_pair_p(a.s) };
    }

    pub fn isPairZ(a: Pair) bool {
        return guile.scm_is_pair(a.s) != 0;
    }
};

//                                           -----------
//                                           List §6.6.9
//                                           -----------

// todo: make generic
// pub const ListTrait = struct {
pub const List = struct {
    s: guile.SCM,

    pub fn len(a: List) Number {
        return .{ .s = guile.scm_length(a.s) };
    }

    pub fn lenZ(a: List) c_long {
        return guile.scm_ilength(a.s);
    }

    //pub fn init(lst: anytype) List {
    //    //        comptime var outlst = []const guile.SCM{};
    //    //        inline for (lst) |scm| {
    //    //            if (!@hasField(@TypeOf(scm), "s")) {
    //    //                @compileError("Can't pass a non scm item into the list: " ++ @typeName(@TypeOf(scm))); // todo improve comp error
    //    //            } else {
    //    //                outlst = outlst ++ .{scm.s};
    //    //            }
    //    //        }
    //    //
    //    //        return .{ .s = @call(.auto, guile.scm_list_n, lst ++ .{guile.SCM_UNDEFINED}) };
    //    const outlst: [lst.len + 1]guile.SCM = undefined;
    //
    //    for (0..lst.len) |idx| {
    //        outlst[idx] = lst[idx].s;
    //    }
    //
    //    outlst[outlst.len] = guile.SCM_UNDEFINED;
    //
    //    return .{ .s = @call(.auto, guile.scm_list_n, outlst) };
    //}

    pub fn init0() List {
        return .{ .s = guile.scm_list_n(guile.SCM_UNDEFINED) };
    }

    pub fn init1(a: anytype) List {
        if (!@hasField(@TypeOf(a), "s")) {
            @compileError("Can't pass a non scm item into the list: " ++ @typeName(@TypeOf(a))); // todo improve comp error
        }
        return .{ .s = guile.scm_list_1(a.s) };
    }

    pub fn init2(a: anytype, b: anytype) List {
        return .{ .s = guile.scm_list_2(a.s, b.s) };
    }

    pub fn append(a: List, b: List) List {
        return .{ .s = guile.scm_append(List.init2(a, b).s) };
    }

    pub fn appendX(a: List, b: List) void {
        _ = guile.scm_append_x(List.init2(a, b).s);
    }

    pub fn cons(a: List, b: anytype) List { // todo typecheck
        return .{ .s = guile.scm_cons(b.s, a.s) };
    }

    //list-ref
};

//                                         --------------
//                                         Vector §6.6.10
//                                         --------------

//                                       ------------------
//                                       Bit Vector §6.6.11
//                                       ------------------

//                                       -------------------
//                                       Byte Vector §6.6.12
//                                       -------------------

// pub const ByteVectorTrait = struct {
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

//                                         --------------
//                                         Arrays §6.6.13
//                                         --------------

//                                          -------------
//                                          VList §6.6.14
//                                          -------------

//                                --------------------------------
//                                Record §6.6.15, §6.6.16, §6.6.17
//                                --------------------------------

//                                        -----------------
//                                        Structure §6.6.18
//                                        -----------------

//                                     -------------------------
//                                     Association Lists §6.6.20
//                                     -------------------------

//                                          -------------
//                                          VHash §6.6.21
//                                          -------------

//================================================+==================================================
//                                        -----------------
//                                        HashTable §6.6.22
//                                        -----------------

//                                   --------------------------
//                                   Primitive Procedures §6.7.2
//                                   --------------------------

fn wrapZig(f: anytype) *const fn (...) callconv(.C) guile.SCM {
    const fi = switch (@typeInfo(@TypeOf(f))) {
        .Fn => |fi| fi,
        else => @compileError("Only wraps Functions"),
    }; //todo: could improve errors here.

    //todo: is there a better way of building a tuple for the `@call`?
    comptime var fields: [fi.params.len]std.builtin.Type.StructField = undefined;

    //todo: type check fn params so they are scm wrappers
    inline for (fi.params, 0..) |p, i| {
        // zig fmt: off
        fields[i] = std.builtin.Type.StructField{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = p.type.?, // optional for anytype?
            .default_value = null,
            .is_comptime = false,
            .alignment = 0
        };
        // zig fmt: on
    }

    const Args = @Type(.{
        .Struct = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = true,
        },
    });

    return struct {
        //todo: use options as guile optional parms
        //todo: consider implicied type conversion guile.SCM => i32 (other then Number)
        //todo: type check with `assert` for ForeignTypes and `isZ` for inbuilt?
        //todo: return type of tuple as a scm_values returns
        fn wrapper(...) callconv(.C) guile.SCM {
            var args: Args = undefined;

            var varg = @cVaStart();
            inline for (fi.params, 0..) |p, i| {
                args[i] = @as(p.type.?, .{ .s = @cVaArg(&varg, guile.SCM) });
            }
            @cVaEnd(&varg);

            const out = @call(.auto, f, args);

            //todo: simplify switch
            switch (@typeInfo(fi.return_type.?)) {
                .ErrorUnion => |eu| {
                    if (out) |ok| {
                        switch (eu.payload) {
                            void => {
                                return guile.SCM_UNDEFINED;
                            },
                            guile.SCM => {
                                return ok;
                            },
                            else => {
                                return ok.s; //todo: check that return is a scm wrapper
                            },
                        }
                    } else |err| {
                        //todo: format error name scm style (eg. dash over camel case)
                        guile.scm_throw(Symbol.from(@errorName(err)).s, List.init0().s);
                    }
                },
                else => {
                    switch (fi.return_type.?) {
                        void => {
                            return guile.SCM_UNDEFINED;
                        },
                        guile.SCM => {
                            return out;
                        },
                        else => {
                            return out.s; //todo: check that return is a scm wrapper
                        },
                    }
                },
            }
        }
    }.wrapper;
}

pub fn defineGSubR(name: [:0]const u8, comptime ff: anytype) Procedure {
    const ft = switch (@typeInfo(@TypeOf(ff))) {
        .Fn => |fs| fs,
        else => @compileError("Bad fn"), // todo: improve error
    };

    return .{ .s = guile.scm_c_define_gsubr(name.ptr, ft.params.len, 0, 0, @constCast(@ptrCast(wrapZig(ff)))) };
}

pub fn defineGSubRAndExport(name: [:0]const u8, comptime ff: anytype) Procedure {
    const scmf = defineGSubR(name, ff);

    guile.scm_c_export(name, guile.NULL);

    return scmf;
}

//                                      --------------------
//                                      General Utility §6.9
//                                      --------------------

//todo: typecheck
pub fn eq(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eq_p(a.s, b.s) };
}

//todo: typecheck
pub fn eqv(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

//todo: typecheck
pub fn equal(a: anytype, b: anytype) Boolean {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

//todo: typecheck
pub fn eqZ(a: anytype, b: anytype) bool {
    return .{ .s = guile.scm_is_eq(a.s, b.s) };
}

//                                      ---------------------
//                                      Foreign Objects §6.20
//                                      ---------------------

pub fn makeForeignObjectType1(name: Symbol, slot: Symbol) ForeignType {
    return .{ .s = guile.scm_make_foreign_object_type(name.s, guile.scm_list_1(slot.s), null) };
}

//todo add checks
pub fn SetupFT(comptime ft: type, comptime cct: type, name: [:0]const u8, slot: [:0]const u8) type {
    return struct {
        var scmType: ForeignType = undefined;
        const CType: type = cct;

        pub fn assert(a: guile.SCM) void {
            guile.scm_assert_foreign_object_type(scmType.s, a);
        }

        pub fn registerType() void {
            scmType = makeForeignObjectType1(Symbol.from(name), Symbol.from(slot));
        }

        pub fn makeSCM(data: *cct) ft {
            return .{ .s = guile.scm_make_foreign_object_1(scmType.s, data) };
        }

        // const mak = if (@sizeOf(cct) <= @sizeOf(*anyopaque)) i32 else i16;
        // todo: It's possible to store small data inside the pointer rather then alloc
        pub fn retrieve(a: ft) ?*cct {
            const p = guile.scm_foreign_object_ref(a.s, 0);

            return if (p == null) null else @alignCast(@ptrCast(p.?));
        }

        pub fn make(alloct: std.mem.Allocator) !*cct {
            return alloct.create(CType);
        }
    };
}

// todo: remember_upto_here
// todo: Fluids
// todo: Hooks

// todo: type check t
pub fn withContinuationBarrier(captures: anytype, comptime t: type) void {
    const ContinuationBarrierC = struct {
        fn barrier(data: ?*anyopaque) callconv(.C) ?*anyopaque {
            t.barrier(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }
    };

    //todo: check for null on exception and how exception should be handled
    _ = guile.scm_c_with_continuation_barrier(ContinuationBarrierC.barrier, @constCast(@ptrCast(&captures)));
}

// todo: io

//todo type check
pub fn defineModule(name: [:0]const u8, df: anytype) Module {
    const f = struct {
        pub fn cModuleDefine(_: ?*anyopaque) callconv(.C) void {
            df();
        }
    };

    return .{ .s = guile.scm_c_define_module(name, f.cModuleDefine, null) };
}

pub fn newline() void {
    _ = guile.scm_newline(guile.scm_current_output_port());
}

pub fn display(a: anytype) void {
    _ = guile.scm_display(a.s, guile.scm_current_output_port());
}

//todo  ptr type checking
pub fn catchException(key: [:0]const u8, captures: anytype, comptime t: type) void {
    const ExpC = struct {
        fn body(data: ?*anyopaque) callconv(.C) guile.SCM {
            t.body(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }

        // zig fmt: off
        fn handler(data: ?*anyopaque, _key: guile.SCM, args: guile.SCM) callconv(.C) guile.SCM {
            t.handler(@as(*@TypeOf(captures), @alignCast(@ptrCast(data))),
                      Symbol{ .s = _key },
                      Any{ .s = args });

            return guile.SCM_UNDEFINED;
        }
    };

    _ = guile.scm_internal_catch(Symbol.from(key).s,
                                 ExpC.body   , @constCast(@ptrCast(&captures)),
                                 ExpC.handler, @constCast(@ptrCast(&captures)));
            // zig fmt: on
}

pub fn UnionSCM(scmTypes: anytype) type {
    //todo: check for tuple of types of scms
    comptime var uf: [scmTypes.len]std.builtin.Type.UnionField = undefined;
    comptime var ef: [scmTypes.len]std.builtin.Type.EnumField = undefined;

    // check if greater then lower case alphabet
    inline for (scmTypes, 0..) |t, i| {
        //todo: check the types

        uf[i] = std.builtin.Type.UnionField{ .alignment = 0, .name = &[_:0]u8{0x61 + i}, .type = t };
        ef[i] = std.builtin.Type.EnumField{ .name = &[_:0]u8{0x61 + i}, .value = i };

        //todo the type names will be wrong.
    }

    // zig fmt: off
    const ET = @Type(.{
        .Enum = .{
            .tag_type = u8,
            .fields = &ef,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true
    }});

    return @Type(.{
        .Union = .{
            .layout = .auto,
            .tag_type = ET,
            .fields = &uf,
            .decls = &[_]std.builtin.Type.Declaration{}
    }});
    // zig fmt: on
}

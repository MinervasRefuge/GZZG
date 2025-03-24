// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;
const iw    = gzzg.internal_workings;

const orUndefined = gzzg.orUndefined;

const Any       = gzzg.Any;
const Character = gzzg.Character;
const Boolean   = gzzg.Boolean;
const String    = gzzg.String;
const Symbol    = gzzg.Symbol;
const Vector    = gzzg.Vector;

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

//                                          -------------
//                                          Number §6.6.2
//                                          -------------

pub const Number = struct {
    s: guile.SCM,

    pub const guile_name = "number";

    pub fn fromZ(comptime n: anytype) Number {
        if (!@import("build_options").enable_comptime_number_creation)
            @compileError("\"enable_comptime_number_creation\" not enabled. Use `from`");

        switch (@typeInfo(@TypeOf(n))) {
            .comptime_int => {
                return .{ .s = @ptrCast(iw.makeFixNum(n)) };
            },
            .@"struct" => |st| { // todo: Does this belong? The divide has to be called at runtime.
                if ((!st.is_tuple) or n.len != 2) @compileError("Expected tuple with two numbers for Rational number");

                inline for (n) |elem| {
                    switch (@typeInfo(@TypeOf(elem))) {
                        .ComptimeInt => {},
                        else => @compileError("Expected tuple with two comptime Integers for Rational number"),
                    }
                }

                return (comptime fromZ(n[0])).divideE(comptime fromZ(n[1]));
            },
            else => @compileError("No comptime number behaviour for type:" ++ @typeName(@TypeOf(n))),
        }
    }

    //todo: is it worth swtching on bit ranges or only standard bit sizes?
    pub fn from(n: anytype) Number {
        const scm = switch (@typeInfo(@TypeOf(n))) {
            .comptime_int => if (@import("build_options").enable_comptime_number_creation)
                fromZ(n).s else
                guile.scm_from_size_t(n),
            .int => |i| switch (i.bits) {
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
            .comptime_float => guile.scm_from_double(n),
            .float         => guile.scm_from_double(@as(f64, n)),
            .@"struct"        => |st| {                
                if ((!st.is_tuple) or n.len != 2) @compileError("Expected tuple with two numbers for Rational number");

                inline for (n) |elem| {
                    switch (@typeInfo(@TypeOf(elem))) {
                        .ComptimeInt, .Int => {},
                        else => @compileError("Expected tuple with two Integers for Rational number")
                    }
                }

                return from(n[0]).divideE(from(n[1]));
            },
            else => @compileError("Type: " ++ @typeName(@TypeOf(n)) ++ " is not part of the numerical tower"),
        };

        return .{ .s = scm };
    }

    pub fn fromRectangular(real: f64, imaginary: f64) Number
        { return .{ .s = guile.scm_c_make_rectangular(real, imaginary) }; }
    pub fn fromPolar(mag: f64, ang: f64) Number { return .{ .s = guile.scm_c_make_polar(mag, ang) }; }

    //todo: error or optional if outside unit size?
    pub fn toZ(a: Number, comptime t: type) t {
        return switch (@typeInfo(t)) {
            .int => |i| switch (i.bits) {
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
            .float => guile.scm_to_double(a.s),
            else => @compileError("Type: " ++ @typeName(@TypeOf(t)) ++ " is not a number"), // todo fix
        };
    }

    pub fn toString(a: Number, radix: ?Number) String { return .{ .s = guile.scm_number_to_string(a.s, gzzg.orUndefined(radix)) }; }
    pub fn toCharacter(a: Number) Character { return .{ .s = guile.scm_integer_to_char(a.s) }; }

    // scm_c_locale_stringn_to_number ?

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_number_p (a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_number(a) != 0; }

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

    pub fn isInf   (a: Number) Boolean { return .{ .s = guile.scm_nan_p(a.s) }; }
    pub fn isFinite(a: Number) Boolean { return .{ .s = guile.scm_finite_p(a.s) }; }

    pub fn isOdd (a: Number) Boolean { return .{ .s = guile.scm_odd_p(a.s) }; }
    pub fn isEven(a: Number) Boolean { return .{ .s = guile.scm_even_p(a.s) }; }

    pub fn isZero    (a: Number) Boolean { return .{ .s = guile.scm_zero_p(a.s) }; }
    pub fn isPositive(a: Number) Boolean { return .{ .s = guile.scm_positive_p(a.s) }; }
    pub fn isNegative(a: Number) Boolean { return .{ .s = guile.scm_negative_p(a.s) }; }

    pub fn lowerZ(a: Number) Any { return .{ .s = a.s }; }
    
    //
    //

    pub fn nan() Number { return .{ .s = guile.scm_nan() }; }
    pub fn inf() Number { return .{ .s = guile.scm_inf() }; }
    pub fn numerator  (a: Number) Number { return .{ .s = guile.scm_numerator(a.s) }; }
    pub fn denominator(a: Number) Number { return .{ .s = guile.scm_denominator(a.s) }; }

    //
    //

    pub fn exactToInexact(a: Number) Number { return .{ .s = guile.scm_exact_to_inexact(a.s) }; }
    pub fn inexactToExact(a: Number) Number { return .{ .s = guile.scm_inexact_to_exact(a.s) }; }

    //
    //

    pub fn modulo(n: Number, d: Number) Number { return .{ .s = guile.scm_modulo(n.s, d.s) }; }
    pub fn gcd   (x: Number, y: Number) Number { return .{ .s = guile.scm_gcd(x.s, y.s) }; }
    pub fn lcm   (x: Number, y: Number) Number { return .{ .s = guile.scm_lcm(x.s, y.s) }; }
    pub fn moduloExpt(n: Number, k: Number, m: Number) Number { return .{ .s = guile.scm_modulo_expt(n.s, k.s, m.s) }; }
    pub fn exactIntegerSqrt(k: Number) .{Number, Number} {
        var s: guile.SCM = undefined;
        var r: guile.SCM = undefined;

        guile.scm_exact_integer_sqrt(k.s, &s, &r);

        return .{ .{ .s = s }, .{ .s = r } };
    }

    //
    //

    pub fn equal           (x: Number, y: Number) Boolean { return .{ .s = guile.scm_num_eq_p(x.s, y.s) }; }
    pub fn lessThan        (x: Number, y: Number) Boolean { return .{ .s = guile.scm_less_p(x.s, y.s) }; }
    pub fn greaterThan     (x: Number, y: Number) Boolean { return .{ .s = guile.scm_gr_p(x.s, y.s) }; }
    pub fn lessThanEqual   (x: Number, y: Number) Boolean { return .{ .s = guile.scm_leq_p(x.s, y.s) }; }
    pub fn greaterThanEqual(x: Number, y: Number) Boolean { return .{ .s = guile.scm_geq_p(x.s, y.s) }; }

    //
    //

    pub fn rectangular(real: Number, imaginary: Number) Number
        { return .{ .s = guile.scm_make_rectangular(real.s, imaginary.s) }; }
    
    pub fn polar(mag: Number, ang: Number) Number { return .{ .s = guile.scm_make_polar(mag.s, ang.s) }; }

    pub fn realPart (a: Number) Number { return .{ .s = guile.scm_real_part(a.s) }; }
    pub fn imagPart (a: Number) Number { return .{ .s = guile.scm_imag_part(a.s) }; }

    pub fn realPartZ(a: Number) f64 { return .{ .s = guile.scm_c_real_part(a.s) }; }
    pub fn imagPartZ(a: Number) f64 { return .{ .s = guile.scm_c_imag_part(a.s) }; }

    pub fn magnitude(a: Number) Number { return .{ .s = guile.scm_magnitude(a.s) }; }
    pub fn angle    (a: Number) Number { return .{ .s = guile.scm_angle(a.s) }; }
    
    //
    //

    pub fn sum       (a: Number, b: ?Number) Number { return .{ .s = guile.scm_sum       (a.s, orUndefined(b)) }; }
    pub fn difference(a: Number, b: ?Number) Number { return .{ .s = guile.scm_difference(a.s, orUndefined(b)) }; }
    pub fn product   (a: Number, b: ?Number) Number { return .{ .s = guile.scm_product   (a.s, orUndefined(b)) }; }
    pub fn divide    (a: Number, b: ?Number) Number { return .{ .s = guile.scm_divide    (a.s, orUndefined(b)) }; }

    pub fn onePlus (a: Number)            Number { return .{ .s = guile.scm_oneplus(a.s) }; }
    pub fn oneMinus(a: Number)            Number { return .{ .s = guile.scm_oneminus(a.s) }; }
    pub fn abs     (a: Number)            Number { return .{ .s = guile.scm_abs(a.s) }; }
    pub fn max     (a: Number, b: Number) Number { return .{ .s = guile.scm_max(a.s, b.s) }; }
    pub fn min     (a: Number, b: Number) Number { return .{ .s = guile.scm_min(a.s, b.s) }; }
    pub fn truncate(a: Number)            Number { return .{ .s = guile.scm_truncate_number(a.s) }; }
    pub fn round   (a: Number)            Number { return .{ .s = guile.scm_round_number(a.s) }; }
    pub fn floor   (a: Number)            Number { return .{ .s = guile.scm_floor(a.s) }; }
    pub fn ceiling (a: Number)            Number { return .{ .s = guile.scm_ceiling(a.s) }; }
    // scm_c_truncate?
    // scm_c_round?
    // scm_euclidean_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // SCM scm_euclidean_quotient (SCM X, SCM Y)
    // SCM scm_euclidean_remainder
    
    // void scm_floor_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // SCM scm_floor_quotient (X, Y)
    // SCM scm_floor_remainder (X, Y)
    
    // void scm_ceiling_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // SCM scm_ceiling_quotient (X, Y)
    // SCM scm_ceiling_remainder (X, Y)
    
    // void scm_truncate_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // SCM scm_truncate_quotient (X, Y)
    // SCM scm_truncate_remainder (X, Y)

    // scm_centered_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // scm_centered_quotient (SCM X, SCM Y)
    // scm_centered_remainder (SCM X, SCM Y)

    // void scm_round_divide (SCM X, SCM Y, SCM *Q, SCM *R)
    // SCM scm_round_quotient (X, Y)
    // SCM scm_round_remainder (X, Y)

    //
    //

    // §6.6.2.12 Scientific Functions
    pub fn sqrt (a: Number)            Number { return .{ .s = guile.scm_sqrt(a.s) }; }
    pub fn expt (a: Number, p: Number) Number { return .{ .s = guile.scm_expt(a.s, p.s) }; }
    pub fn sin  (a: Number)            Number { return .{ .s = guile.scm_sin(a.s) }; }
    pub fn cos  (a: Number)            Number { return .{ .s = guile.scm_cos(a.s) }; }
    pub fn tan  (a: Number)            Number { return .{ .s = guile.scm_tan(a.s) }; }
    pub fn asin (a: Number)            Number { return .{ .s = guile.scm_asin(a.s) }; }
    pub fn acos (a: Number)            Number { return .{ .s = guile.scm_acos(a.s) }; }
    //pub fn atan(a: Number)            Number { return .{ .s = guile.scm_(a.s) }; }
    pub fn exp  (a: Number)            Number { return .{ .s = guile.scm_exp(a.s) }; }
    pub fn log  (a: Number)            Number { return .{ .s = guile.scm_log(a.s) }; }
    pub fn log10(a: Number)            Number { return .{ .s = guile.scm_log10(a.s) }; }
    pub fn sinh (a: Number)            Number { return .{ .s = guile.scm_sinh(a.s) }; }
    pub fn cosh (a: Number)            Number { return .{ .s = guile.scm_cosh(a.s) }; }
    pub fn tanh (a: Number)            Number { return .{ .s = guile.scm_tanh(a.s) }; }
    pub fn asinh(a: Number)            Number { return .{ .s = guile.scm_asinh(a.s) }; }
    pub fn acosh(a: Number)            Number { return .{ .s = guile.scm_acosh(a.s) }; }
    pub fn atanh(a: Number)            Number { return .{ .s = guile.scm_atanh(a.s) }; }

    //
    //

    // §6.6.2.13 Bitwise Operations
    pub fn logAnd (a: Number, b: Number)   Number  { return .{ .s = guile.scm_logand(a.s, b.s) }; }
    pub fn logIOr (a: Number, b: Number)   Number  { return .{ .s = guile.scm_logior(a.s, b.s) }; }
    pub fn logXOr (a: Number, b: Number)   Number  { return .{ .s = guile.scm_logxor(a.s, b.s) }; }
    pub fn logNot (a: Number, b: Number)   Number  { return .{ .s = guile.scm_lognot(a.s, b.s) }; }
    pub fn logTest(a: Number, b: Number)   Boolean { return .{ .s = guile.scm_logtest(a.s, b.s) }; }
    pub fn logBit (a: Number, idx: Number) Boolean { return .{ .s = guile.scm_logbit_p(a.s, idx.s) }; }
    
    pub fn ash        (a: Number, count: Number) Number { return .{ .s = guile.scm_ash(a.s, count.s) }; }
    pub fn roundAsh   (a: Number, count: Number) Number { return .{ .s = guile.scm_round_ash(a.s, count.s) }; }
    pub fn logCount   (a: Number)                Number { return .{ .s = guile.scm_logcount(a.s) }; }
    pub fn integerLen (a: Number)                Number { return .{ .s = guile.scm_integer_length(a.s) }; }
    pub fn integerExpt(a: Number, k: Number)     Number { return .{ .s = guile.scm_integer_expt(a.s, k.s) }; }
    pub fn bitExtract (a: Number, start: Number, end: Number) Number
        { return .{ .s = guile.scm_bit_extract(a.s, start.s, end.s) }; }

    //
    //

    // §6.6.2.14 Random Number Generation
    pub const RandomState = struct {
        s: guile.SCM,

        pub fn fromPlatform() RandomState { return .{ .s = guile.scm_random_state_from_platform() }; }

        // (set! *random-state* (random-state-from-platform)) ?
    };

    pub fn random(n: Number, state: ?RandomState) Number
        { return .{ .s = guile.scm_random(n.s, gzzg.orUndefined(state))}; }
    
    pub fn randomExpt(state: ?RandomState) Number
        { return .{ .s = guile.scm_random_exp(gzzg.orUndefined(state)) }; }
    
    pub fn randomHollowSphereX(v: Vector, state: ?RandomState) void
        { _ = guile.scm_random_hollow_sphere_x(v.s, gzzg.orUndefined(state)); }
    
    pub fn randomNormal(state: ?RandomState) Number
        { return .{ .s = guile.scm_random_normal(gzzg.orUndefined(state)) }; }
    
    pub fn randomNormalVectorX(v: Vector, state: ?RandomState) void
        { _ = guile.scm_random_normal_vector_x(v.s, gzzg.orUndefined(state)); }
    
    pub fn randomSolidSphereX(v: Vector, state: ?RandomState) void
        { _ = guile.scm_random_solid_sphere_x(v.s, gzzg.orUndefined(state)); }
    
    pub fn randomUniform(state: ?RandomState) Number
        { return .{ .s = guile.scm_random_uniform(gzzg.orUndefined(state)) }; }

    // seed->random-state seed
    // datum->random-state datum
    // random-state->datum state

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

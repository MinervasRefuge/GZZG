// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;
const Type  = std.builtin.Type;

const GZZGType = gzzg.contracts.GZZGType;

const Any        = gzzg.Any;
const Boolean    = gzzg.Boolean;
const ByteVector = gzzg.ByteVector;
const Character  = gzzg.Character;
const Integer    = gzzg.Integer;
const List       = gzzg.List;
const ListOf     = gzzg.ListOf;
const Module     = gzzg.Module;
const Number     = gzzg.Number;
const PairOf     = gzzg.PairOf;
const Port       = gzzg.Port;
const String     = gzzg.String;
const Symbol     = gzzg.Symbol;
const Vector     = gzzg.Vector;

const StaticCache = gzzg.StaticCache;
const UnionOf     = gzzg.UnionOf;

//
// Note: WIP, As of current, find this code to be a mess and not as clear as it should be.

fn OptionalOf(comptime T: type) GZZGType(T, type) {
    return UnionOf(.{ Boolean, T });
}

const AList = ListOf(PairOf(Symbol, Any));

pub const basic = struct {
    pub const Hint = struct {
        u8_array_is: U8ArrayIs = .string,
        use_sized_array: bool = false, // unimplemented
        u21_as_character: bool = false,
        sequence: Sequence = .list,
        
        const U8ArrayIs = enum {
            string,
            bytevector,

            fn ty(comptime self: @This()) type {
                return switch (self) {
                    .string => String,
                    .bytevector => ByteVector,
                };
            }
        };

        const Sequence = enum {
            list,
            vector,

            fn ty(comptime self: @This()) type {
                return switch (self) {
                    .list => List,
                    .vector => Vector,
                };
            }
        };
    };

    //
    //

    fn FromSequenceLike(comptime Child: type, comptime hint: Hint) type {
        switch (Child) {
            u8 => return hint.u8_array_is.ty(),
            i8 => return ByteVector,
            else => {
                if (hint.use_sized_array) @compileError("Unimplemented");
                return hint.sequence.ty();
            },
        }          
    }
    
    fn From(comptime T: type, comptime hint: Hint) type {
        if (hint.u21_as_character and T == u21) return Character;
        
        recurse: switch (@typeInfo(T)) {
            .comptime_float, .float => return Number,
            .comptime_int, .int => return Integer,
            .array => |arr| return FromSequenceLike(arr.child, hint),
            .@"struct" => |st| {
                if (st.is_tuple) return hint.sequence.ty();
                return AList;
            },
            .pointer => |ptr| {
                switch (ptr.size) {
                    .one => continue :recurse @typeInfo(ptr.child),
                    .many => @compileError("Unknown type to buoy type slice pointer"),
                    .slice => |slc| return FromSequenceLike(slc.child, hint),
                    .c => @compileError("Unknown type to buoy type c pointer"),
                }
            },
            .optional => |op| {
                return OptionalOf(From(op.child, hint));
            },
            else => @compileError("Unknown type to buoy type"),
        }
    }

    //
    //
    
    fn aListFromStruct(value: anytype, comptime hint: Hint) AList {
        const Value = @TypeOf(value);
        const info = @typeInfo(Value).@"struct";
        const Cache = StaticCache(Symbol, Symbol.fromUTF8, std.meta.fieldNames(Value));
        var lst = AList.init(.{});
        
        inline for (info.fields) |field| {
            lst = lst.cons(
                .from(Cache.get(field.name),
                      from(@field(value, field.name), hint).lowerZ())
            );
        }
        
        return lst.reverse();
    }

    // *[4]u8
    // []const ?
    // [2]u8
    // []const [10]i32
    fn sequenceFromArrayLike(value: anytype, comptime hint: Hint) From(@TypeOf(value), hint) {
        const Value = @TypeOf(value);
        const Child = std.meta.Child(Value); 

        switch (Child) {
            u8, i8 => return .from(value), // String or ByteVector
            else => {
                //if (hint.use_sized_array) @compileError("Unimplemented");

                switch (hint.sequence) {
                    .list => {
                        var lst = List.init(.{});
                        
                        for (0..value.len) |idx| 
                            lst = lst.cons(from(value[idx], hint).lowerZ());
                        
                        return lst.reverse();
                    },
                    .vector => {
                        const vec = Vector.makeZ(value.len, null);
                        
                        for (0..value.len) |idx|
                            vec.setXZ(idx, from(value[idx], hint).lowerZ());
                        
                        return vec;
                    },
                }
            },
        }
    }

    fn sequenceFromTuple(value: anytype, info: Type.Struct, comptime hint: Hint) hint.sequence.ty() {
        switch (hint.sequence) {
            .list => {
                var lst = List.init(.{});

                inline for (info.fields) |field| 
                    lst = lst.cons(from(@field(value, field.name)).lowerZ());

                return lst.reverse();
            },
            .vector => {
                const vec = Vector.makeZ(info.fields.len, null);

                inline for (info.fields, 0..) |field, idx|
                    vec.setXZ(idx, from(@field(value, field.name), hint).lowerZ());

                return vec;
            },
        }
    }
    
    pub fn from(value: anytype, comptime hint: Hint) From(@TypeOf(value), hint) {
        const Value = @TypeOf(value);
        
        switch (@typeInfo(Value)) {
            // includes char 
            .comptime_float, .float, .comptime_int, .int => return .from(value),
            .@"struct" => |st| {
                if (st.is_tuple) return sequenceFromTuple(value, st, hint);
                
                return aListFromStruct(value, hint);
            },
            .array => return sequenceFromArrayLike(value, hint),
            .pointer => |ptr| {
                 switch (ptr.size) {
                     .one => return from(value.*, hint),
                     .many => @compileError("BAD"),
                     .slice => return sequenceFromArrayLike(value, hint),
                     .c => @compileError("BAD"),
                 }
            },
            .optional => {
                return .from(
                    if (value) |some| 
                        from(some, hint)
                    else
                        Boolean.falsum);
            },
            else => @compileError("BAD"),
        }
    }
};

//
// Unused functional mapping tool (built in a different codebase originally).
//

inline fn pError(comptime str: []const u8, args: anytype) void {
    @compileError(std.fmt.comptimePrint(str, args));
}

fn MapInput(comptime Fn: type, comptime Lsts: type) type {
    const lsinfo = @typeInfo(Lsts).@"struct";
    const finfo = @typeInfo(Fn).@"fn";
    const len = finfo.params.len;
    var arg_types: [len]type = undefined;

    for (0..len) |i| arg_types[i] = finfo.params[i].type orelse std.meta.fields(lsinfo.fields[i].type)[0].type;

    return std.meta.Tuple(&arg_types);
}

fn MapOutput(comptime Fn: type, comptime len: comptime_int) type {
    const finfo = @typeInfo(Fn).@"fn";

    return std.meta.Tuple(&[1]type{finfo.return_type.?} ** len);
}

fn Map(comptime Fn: type, comptime Lsts: type) type {
    const lsinfo = @typeInfo(Lsts).@"struct";
    const fninfo = @typeInfo(Fn).@"fn";
    const lsname = @typeName(Lsts);

    if (!lsinfo.is_tuple) @compileError("Expected 'Tuple' found: " ++ lsname);
    //if (finfo.is_generic) @compileError("Not implemented"); // happends when any thing is comptime args or return
    if (fninfo.is_var_args) @compileError("Not implemented");
    if (fninfo.params.len != lsinfo.fields.len) @compileError("Wrong number of args for lst or fn");

    var expected_len: ?comptime_int = null; // expected len of sublists;

    for (lsinfo.fields, 0..) |lsf, i| { // for each list
        const L = lsf.type;
        const p = fninfo.params[i];
        const linfo = @typeInfo(L).@"struct";
        const lname = @typeName(L);

        if (!linfo.is_tuple) pError("Expected 'Tuple' on list: {d} found: {s}", .{ i, lname });
        if (linfo.fields.len == 0) pError("Expected 'Tuple' with len on list: {d}", .{i});

        if (expected_len) |el| {
            if (el != linfo.fields.len)
                pError("Lists are of different lengths on list: {d}, expected len: {d}, found len: {d}", .{ i, el, L.len });
        } else {
            expected_len = linfo.fields.len;
        }

        // if `anytype` use the first field type of list to check the rest
        const Expected = p.type orelse linfo.fields[0].type;

        for (linfo.fields, 0..) |finfo, j| {
            if (finfo.type != Expected) {
                // is the type coercible? Unable to check fully.

                if (isNumberType(Expected)) {
                    isCoercibleNumber(finfo.type, Expected);
                } else {
                    pError("Expect type '{s}' on list: {d} at elm: {d}. Got: {s}", .{ @typeName(Expected), i, j, @typeName(finfo.type) });
                }
            }
        }
    }

    return MapOutput(Fn, expected_len.?);
}

inline fn isNumberType(N: type) bool {
    return switch (@typeInfo(N)) {
        .comptime_int, .comptime_float, .int, .float => true,
        else => false,
    };
}

inline fn isCoercibleNumber(comptime A: type, comptime B: type) void {
    const a: A = 0;
    const b: B = 0;

    _ = @TypeOf(a, b);
}

fn map(function: anytype, lists: anytype) Map(@TypeOf(function), @TypeOf(lists)) {
    const Fn = @TypeOf(function);
    const Lists = @TypeOf(lists);
    const len = comptime lists[0].len; // all list are of the same length
    const Args = MapInput(Fn, Lists);
    const Out = MapOutput(Fn, len);

    var out: Out = undefined;

    inline for (0..len) |idx| {
        var args: Args = undefined;

        inline for (lists, 0..) |list, j| {
            args[j] = list[idx]; // ~idx~ needs to be comptime time known for what ever reason.
        }

        out[idx] = @call(.auto, function, args);
    }

    return out;
}

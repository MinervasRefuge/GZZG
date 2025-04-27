// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType             = gzzg.contracts.GZZGType;
const GZZGTypes            = gzzg.contracts.GZZGTypes;
const GZZGTupleOfTypes     = gzzg.contracts.GZZGTupleOfTypes;
const GZZGOptionalType     = gzzg.contracts.GZZGOptionalType;
const GZZGFunctionCallable = gzzg.contracts.GZZGFunctionCallable;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Module  = gzzg.Module;
const Port    = gzzg.Port;
const String  = gzzg.String;
const Symbol  = gzzg.Symbol;

pub fn eval(str: anytype, module: ?Module) Any {
    // string is expect to be in locale encoding
    // the c code just calls scm_from_locale_string.
    // _ = guile.scm_c_eval_string(…);
    // equv to the following

    //todo fix
    // const gs = init: {
    //     switch (@typeInfo(@TypeOf(str))) {
    //         .Array => |a| {
    //             if (a.child != u8) @compileError("Array should have a sub type of u8");
    //             break :init String.fromUTF8(&str);
    //         },
    //         .Pointer => |p| {
    //             if (p.child != u8) @compileError("Slice should have a sub type of u8: " ++ @typeName(p.child));
    //             switch (p.size) {
    //                 .One => @compileError("Bad Pointer type"),
    //                 .Many => {
    //                     if (p.sentinel) |s| {
    //                         if (@as(*u8, @ptrCast(s)) != 0)
    //                             @compileError("Sentinel value must be 0");
    //                         break :init String.fromUTF8CStr(str);
    //                     } else {
    //                         @compileError("Many ptr must have sentinel of :0");
    //                     }
    //                 },
    //                 .Slice => break :init String.fromUTF8(str),
    //                 .C => break :init String.fromUTF8CStr(str),
    //             }
    //         },
    //         .Struct => {
    //             if (@TypeOf(str) != String)
    //                 @compileError("Struct should have been a `String`");
    // 
    //             break :init str;
    //         },
    //         else => @compileError("Not a string: " ++ @typeName(@TypeOf(str))),
    //     }
    // };

    return .{ .s = guile.scm_eval_string_in_module(String.fromUTF8(str).s, orUndefined(module)) };
}

//                                      --------------------
//                                      General Utility §6.9
//                                      --------------------

pub fn eq(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eq_p(a.s, b.s) };
}

pub fn eqv(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

pub fn equal(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), Boolean) {
    return .{ .s = guile.scm_eqv_p(a.s, b.s) };
}

// ~scm_is_eq~ is a macro that depends on ~SCM_UNPACK~ which didn't get translated due to ~volatile~ keyword. So...
// 
// C pointers should only be compared if they are elements of the same array or struct object. A
// round trip from ~void *~ to ~uintptr_t~ to ~void *~ is consider "safe". Hence the cast. Also see
// [[https://www.gnu.org/software/c-intro-and-ref/manual/html_node/Pointer_002dInteger-Conversion.html][c intro | pointer conversion]].
// 
// #+BEGIN_SRC c
//   typedef uintptr_t scm_t_bits;
//   #define SCM_UNPACK(x) ((scm_t_bits) (0? (*(volatile SCM *)0=(x)): x))
//   #define scm_is_eq(x, y) (SCM_UNPACK (x) == SCM_UNPACK (y))
// #+END_SRC
// 
// Zig allows ptr comparison as long as both types are the same ~&T == &T~ otherwise ~@intFromPtr~
// is the alternative. The equivalent with visual intent should be...

pub fn eqZ(a: anytype, b: anytype) GZZGTypes(@TypeOf(.{ a, b }), bool) {
    return @intFromPtr(a.s) == @intFromPtr(b.s);
}

// todo: remember_upto_here
// todo: Fluids
// todo: Hooks

/// used much like the `@call` function
/// exceptions do get chomped, though printed to the error port
/// `Ret` type used as an alternative return type if the function is generic and doesn't return a type.
/// returns `GuileError` on barrier caught else the `Ret` type
pub fn withContinuationBarrier(function: anytype, comptime Ret: ?type, args: anytype)
    error{GuileError}!GZZGFunctionCallable(@TypeOf(function), Ret, @TypeOf(args))
{
    const args_ptr, const ArgsPtr = init: switch (@typeInfo(@TypeOf(args))) {
        .@"struct" => |ist| {
            if (!ist.is_tuple) @compileError("Expect tuple");

            break :init .{ &args, @TypeOf(&args) };
        },
        .pointer => |iptr| {
            if (iptr.size != .one) @compileError("Expeced ptr to one thing");
            switch (@typeInfo(iptr.child)) {
                .@"struct" => |ipst| {
                    if (!ipst.is_tuple) @compileError("Expect ptr to tuple");

                    break :init .{ args, @TypeOf(args) };
                },
                else => @compileError("Expected ptr to tuple"),
            }
        },
        else => @compileError("Expected ptr to tuple or tuple"),
    };

    const Return  = @typeInfo(@TypeOf(function)).@"fn".return_type orelse Ret.?;
    const rules   = comptime std.math.order(@sizeOf(Return), @sizeOf(?*anyopaque));
    const MaskInt = @Type(.{ .int = .{ .bits = @bitSizeOf(Return), .signedness = .unsigned } });
    
    const Barrier = struct {
        inline fn pack(value: Return) *anyopaque {    
            return switch (@typeInfo(Return)) {
                .pointer => @ptrCast(value),
                else => switch (rules) {
                    .gt => @compileError("Type too large to return"),
                    .eq,
                    .lt => @ptrFromInt(@as(MaskInt, @bitCast(value))),
                },
            };
        }
        
        inline fn unpack(value: *anyopaque) Return {
            return switch (@typeInfo(Return)) {
                .pointer => @alignCast(@ptrCast(value)),
                else => @bitCast(@as(MaskInt, @truncate(@intFromPtr(value)))),
            };
        }
        
        fn barrier(data: ?*anyopaque) callconv(.c) ?*anyopaque {
            const brr_args: ArgsPtr = @alignCast(@ptrCast(data.?));
            const brr_out = @call(.always_inline, function, brr_args.*);

            // the only place you can check generic function return types;
            comptime std.debug.assert(@TypeOf(brr_out) == Return);

            // return some value to be able to check if barrier return safely
            if (Return == void) {
                return @ptrFromInt(@intFromBool(true));
            } else {
                return pack(brr_out);
            }
        }
    };

    // args must be a pointer to the args passed to ff
    // return type must be a type equal to or smaller than a pointer.

    const out_ptr = guile.scm_c_with_continuation_barrier(
        Barrier.barrier,
        @constCast(@ptrCast(args_ptr))
    );

    if (Return == void) {
        return if (out_ptr) {} else error.GuileError;
    } else {
        return if (out_ptr) |ptr| Barrier.unpack(ptr) else error.GuileError;
    }
}

pub fn newline() void {
    _ = guile.scm_newline(Port.current.output().s);
}

pub fn display(a: anytype) GZZGType(@TypeOf(a), void) {
    _ = guile.scm_display(a.s, Port.current.output().s);
}

pub fn newlineErr() void {
    _ = guile.scm_newline(Port.current.@"error"().s);
}

pub fn displayErr(a: anytype) GZZGType(@TypeOf(a), void) {
    _ = guile.scm_display(a.s, Port.current.@"error"().s);
}

//todo ptr type checking
pub fn catchException(key: [:0]const u8, comptime Captures: type, captures: *const Captures, comptime T: type) void {
    const ExpC = struct {
        fn body(data: ?*anyopaque) callconv(.c) guile.SCM {
            T.body(@as(*const Captures, @alignCast(@ptrCast(data))));

            return guile.SCM_UNDEFINED;
        }

        fn handler(data: ?*anyopaque, _key: guile.SCM, args: guile.SCM) callconv(.c) guile.SCM {
            T.handler(@as(*const Captures, @alignCast(@ptrCast(data))),
                      Symbol{ .s = _key },
                      Any{ .s = args });

            return guile.SCM_UNDEFINED;
        }
    };

    //todo: is internal catch correct?
    _ = guile.scm_internal_catch(Symbol.fromUTF8(key).s,
                                 ExpC.body   , @constCast(@ptrCast(captures)),
                                 ExpC.handler, @constCast(@ptrCast(captures)));
}

pub fn catchExceptionC(key: [:0]const u8, comptime Captures: type, captures: *const Captures,
                       body:  *const fn (data: *Captures) callconv(.c) Any,
                       handler: *const fn (data: *Captures, key: Symbol, args: Any) callconv(.c) Any) void {

    //todo: is internal catch correct?
    _ = guile.scm_internal_catch(Symbol.from(key).s,
                                 @ptrCast(body)   , @constCast(@ptrCast(captures)),
                                 @ptrCast(handler), @constCast(@ptrCast(captures)));

    comptime { // check hacky cast
        if (@sizeOf(Symbol) != @sizeOf(guile.SCM) or
               @sizeOf(Any) != @sizeOf(guile.SCM)) 
            @compileError("Bad Sizes");
    }
}

pub fn orUndefined(a: anytype) GZZGOptionalType(@TypeOf(a), guile.SCM) {
    return if (a == null) Any.UNDEFINED.s else a.?.s;
}

// todo: consider changing strs input type to anytype and check if list of strings or enum (or union?).
// todo: also check the constructor type stuff.
pub fn StaticCache(GType: type, constructor: anytype, strs: []const []const u8) type {
    return struct {
        var container = [1]?GType{null} ** strs.len;

        fn index(comptime str: []const u8) usize {
            for (strs, 0..) |in_str, idx| {
                if (std.mem.eql(u8, in_str, str))
                    return idx;
            }

            @compileError("Not an member of the static lookup: " ++ str);
        }

        pub fn get(comptime str: []const u8) GType {
            const idx = comptime index(str);

            if (container[idx] == null) {
                container[idx] = constructor(str);
            }

            return container[idx].?;
        }

        pub fn fromEnum(comptime Enum: type, sym: Symbol) ?Enum {
            // todo: use symbol.hash in comptime
            const len = comptime init: {
                var max = 0;
                for (std.meta.tags(Enum)) |tag| max = @max(max, @tagName(tag).len);

                break :init max;
            };
            const str_buf: [len + 1]u8 = undefined;
            const buffer  = std.heap.FixedBufferAllocator.init(&str_buf);
            const sym_str = sym.toString().toUTF8(buffer.allocator()) catch unreachable;
            
            inline for (std.meta.tags(Enum)) |tag| {
                if (std.mem.eql(u8, @tagName(tag), sym_str)) return tag;
            }

            return null;
        }
    };
}

fn guileToZigName(comptime name: [:0]const u8) [name.len:0]u8 {
    var out: [name.len:0]u8 = undefined;

    //todo: consider capitals
    for (name, 0..) |c, i| {
        switch (c) {
            '-' => out[i] = '_',
            else => out[i] = c,
        }
    }

    return out;
}

/// Takes in a tuple of scm container types
pub fn UnionOf(comptime scmTypes: anytype) GZZGTupleOfTypes(scmTypes, type) {
    const Type = std.builtin.Type;
    const len = scmTypes.len + 1;

    var enum_fields: [len]Type.EnumField = undefined;
    var union_fields: [len]Type.UnionField = undefined;

    inline for (scmTypes, 0..) |St, i| {
        const name:[:0]const u8 = &guileToZigName(St.guile_name); // is this safe?
        
        enum_fields [i] = .{ .name = name, .value = i };
        union_fields[i] = .{ .name = name, .type = St, .alignment = @alignOf(guile.SCM) };
    }

    enum_fields [len-1] = .{ .name = Any.guile_name, .value = len-1 };
    union_fields[len-1] = .{ .name = Any.guile_name, .type = Any, .alignment = @alignOf(guile.SCM) };

    const SCMEnum = @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, len),
            .fields = &enum_fields,
            .decls = &[_]Type.Declaration{},
            .is_exhaustive = true
    }});

    const SCMUnion = @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = SCMEnum,
            .fields = &union_fields,
            .decls = &[_]Type.Declaration{}
    }});
 
    return struct {
        s: guile.SCM,

        pub fn get(a: @This(), comptime SCMType: type) ?SCMType {
            if (comptime std.mem.indexOfScalar(type, scmTypes, SCMType) == null)
                @compileError(@typeName(SCMType) ++ " not a member of this scm union");

            return if (SCMType.isZ(a.s)) .{ .s = a.s } else null;
        }

        pub fn decide(a: @This()) SCMUnion {
            inline for(std.meta.fields(SCMUnion)) |field| {
                if (comptime !std.mem.eql(u8, field.name, Any.guile_name))
                    if (field.type.isZ(a.s)) @unionInit(SCMUnion, field.name, .{ .s = a.s });
            }

            return @unionInit(SCMUnion, Any.guile_name, .{ .s = a.s });
        }

        pub fn into(a: anytype) GZZGType(@TypeOf(a), @This()) {
            if (comptime std.mem.indexOfScalar(type, &scmTypes, @TypeOf(a)) == null)
                @compileError("Not a member of this Union: " ++ @typeName(@TypeOf(a)));

            return .{ .s = a.s };
        }

        pub fn lowerZ(a: @This()) Any { return .{ .s = a.s }; }
    };
}

// §6.11.7 Returning and Accepting Multiple Values
pub fn MultiValue(comptime scmTypes: anytype) GZZGTupleOfTypes(scmTypes, type) {
    if (scmTypes.len < 2) @compileError("Should be more than one value type");
    const len = scmTypes.len;
    var typeArray:[len]type = undefined;
    //comptime var name = "(values";

    inline for(scmTypes, 0..) |SCMType, idx| {
        typeArray[idx] = SCMType;
        //name = name ++ " " ++ SCMType.guile_name;
    }
    
    const ValuesTuple = std.meta.Tuple(&typeArray);
    //name = name ++ ")";

    return struct {
        s: guile.SCM,

        pub const Values = scmTypes;
        pub const Tuple = ValuesTuple;
        pub const guile_name = "values";//name;

        pub fn is (a: guile.SCM) Boolean { return .from(isZ(a)); }
        pub fn isZ(a: guile.SCM) bool    { return guile.scm_c_nvalues(a) != 1; }
        pub fn lowerZ(a: @This()) Any    { return .{ .s = a.s }; }
        
        pub fn toTuple(a: @This()) Tuple {
            std.debug.assert(guile.scm_c_nvalues(a.s) == len);
            
            const v: Tuple = undefined;
            inline for (0..len) |idx| v[idx] = guile.scm_c_value_ref(a.s, idx);
            return v;
        }

        pub fn fromTuple(v: Tuple) @This() {
            return .{ .s = guile.scm_values(gzzg.ListOf(Any).initUnsafe(v).s) };
        }

        // Note that this looses the typeing
        pub fn fromArray(v: [len]guile.SCM) @This() {
            return .{ .s = guile.scm_c_values(&v, len) };
        }

        comptime {
            _ = gzzg.contracts.GZZGType(@This(), void);
        }
    };
}

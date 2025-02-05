// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const Number = gzzg.Number;

//                                           -----------
//                                           Pair §6.6.8
//                                           -----------

pub const Pair = struct {
    s: guile.SCM,

    // zig fmt: off
    // todo: typecheck
    pub fn from(x: anytype, y: anytype) Pair { return .{ .s = guile.scm_cons(x.s, y.s) }; }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_pair_p(a.s) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_pair(a.s) != 0; }

    pub fn lowerZ(a: Pair) Any { return .{ .s = a.s }; }
};

//                                           -----------
//                                           List §6.6.9
//                                           -----------

// todo: make generic
pub const List = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_list_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }  // where's the companion fn?

    pub fn lowerZ(a: List) Any { return .{ .s = a.s }; }
    
    pub fn len (a: List) Number { return .{ .s = guile.scm_length(a.s) }; }
    pub fn lenZ(a: List) c_long { return guile.scm_ilength(a.s); }
    // zig fmt: on

    pub fn init(lst: anytype) List {
        //todo: again, is there a better way to compose a tuple at comptime?
        comptime var fields: [lst.len + 1]std.builtin.Type.StructField = undefined;

        inline for (0..fields.len) |i| {
            // zig fmt: off
            fields[i] = std.builtin.Type.StructField{
                .name = std.fmt.comptimePrint("{d}", .{i}),
                .type = guile.SCM,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0
            };
            // zig fmt: on
        }

        const SCMTuple = @Type(.{
            .Struct = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = true,
            },
        });
        var outlst: SCMTuple = undefined;

        inline for (lst, 0..) |scm, idx| {
            if (!@hasField(@TypeOf(scm), "s")) {
                @compileError("Can't pass a non scm item into the list: " ++ @typeName(@TypeOf(scm))); // todo improve comp error
            } else {
                outlst[idx] = scm.s;
            }
        }

        outlst[lst.len] = guile.SCM_UNDEFINED;

        return .{ .s = @call(.auto, guile.scm_list_n, outlst) };
    }

    pub fn append(a: List, b: List) List {
        return .{ .s = guile.scm_append(List.init(.{ a, b }).s) };
    }

    //todo: check is this working?
    pub fn appendX(a: List, b: List) void {
        _ = guile.scm_append_x(List.init(.{ a, b }).s);
    }

    pub fn cons(a: List, b: anytype) List { // todo typecheck
        return .{ .s = guile.scm_cons(b.s, a.s) };
    }

    pub fn reverse(a: List) List {
        return .{ .s = guile.scm_reverse(a.s) };
    }

    //list-ref
};

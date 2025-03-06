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

    pub fn isNull(a: List) Boolean { return .{ .s = guile.scm_null_p(a.s) }; }
    // pub fn isNullZ(a: List) bool { return guile.scm_is_null(a.s) != 0; } // is null didn't translate correctly

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
                .default_value_ptr = null,
                .is_comptime = false,
                .alignment = 0
            };
            // zig fmt: on
        }

        const SCMTuple = @Type(.{
            .@"struct" = .{
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

    // zig fmt: off
    pub fn copy(a: List) List { return .{ .s = guile.scm_list_copy(a.s) }; }
    pub fn append(a: List, b: List) List { return .{ .s = guile.scm_append(List.init(.{ a, b }).s) }; }
    //todo: check is this working?
    pub fn appendX(a: List, b: List) void { _ = guile.scm_append_x(List.init(.{ a, b }).s); }
    //todo: type check
    pub fn cons(a: List, b: anytype) List { return .{ .s = guile.scm_cons(b.s, a.s) }; }
    pub fn reverse(a: List) List { return .{ .s = guile.scm_reverse(a.s) }; }
    // pub fn reverseX(a: *List, newtail: Any) void { 
    
    pub fn ref(a: List, idx: Number) Any { return .{ .s = guile.scm_list_ref(a.s, idx.s) }; }
    // list-tail
    // list-head

    //list-set!
    //list-cdr-set!
    pub fn delq  (a: List, item: anytype) List { return .{ .s = guile.scm_d4elq(item.s, a.s) }; }
    pub fn delv  (a: List, item: anytype) List { return .{ .s = guile.scm_delv(item.s, a.s) }; }
    pub fn delete(a: List, item: anytype) List { return .{ .s = guile.scm_delete(item.s, a.s) }; }

    pub fn delqX  (a: List, item: anytype) void { _ = guile.scm_delq_x(item.s, a.s); }
    pub fn delvX  (a: List, item: anytype) void { _ = guile.scm_delv_x(item.s, a.s); }
    pub fn deleteX(a: List, item: anytype) void { _ = guile.scm_delete_x(item.s, a.s); }

    pub fn delq1X  (a: List, item: anytype) void { _ = guile.scm_delq1_x(item.s, a.s); }
    pub fn delv1X  (a: List, item: anytype) void { _ = guile.scm_delv1_x(item.s, a.s); }
    pub fn delete1X(a: List, item: anytype) void { _ = guile.scm_delete1_x(item.s, a.s); }
    //filter

    pub fn memq  (_: List, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}
    pub fn memv  (_: List, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}
    pub fn member(_: List, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}

    //map

    pub fn iterator(a: List) ConstListIterator {
        return .{
            .head = a,
            .l = a
        };
    }
};

pub const ConstListIterator = struct {
    head: List,
    l: List,

    const Self = @This();

    pub fn next(self: *Self) ?Any {
        if (self.l.isNull().toZ()) {
            return null;
        } else {
            defer self.l = .{ .s = guile.scm_cdr(self.l.s) };
            
            return .{ .s = guile.scm_car(self.l.s) };
        }
    }

    pub fn peek(self: *Self) ?Any {
        if (self.l.isNull().toZ()) {
            return null;
        } else {
            return .{ .s = guile.scm_car(self.l.s) };
        }
    }
    
    pub fn reset(self: *Self) void {
        self.l = self.head;
    }
};

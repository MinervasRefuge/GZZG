// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGTypes = gzzg.contracts.GZZGTypes;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Number  = gzzg.Number;

//                                           -----------
//                                           Pair §6.6.8
//                                           -----------

pub const Pair = struct {
    s: guile.SCM,

    // todo: typecheck
    pub fn from(x: anytype, y: anytype) Pair { return .{ .s = guile.scm_cons(x.s, y.s) }; }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_pair_p(a.s) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_pair(a.s) != 0; }

    pub fn lowerZ(a: Pair) Any { return .{ .s = a.s }; }
};

//                                           -----------
//                                           List §6.6.9
//                                           -----------

pub fn ListOf(comptime T: type) type {
    return struct {
        s: guile.SCM,

        const Self = @This();
        const Child = T;
        
        pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_list_p(a) }; }
        pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }  // where's the companion fn?
        
        pub fn isNull(a: Self) Boolean { return .{ .s = guile.scm_null_p(a.s) }; }
        // pub fn isNullZ(a: List) bool { return guile.scm_is_null(a.s) != 0; } // is null didn't translate correctly
        
        pub fn lowerZ(a: Self) Any { return .{ .s = a.s }; }
        
        pub fn len (a: Self) Number { return .{ .s = guile.scm_length(a.s) }; }
        pub fn lenZ(a: Self) c_long { return guile.scm_ilength(a.s); }
        
        pub fn init(lst: anytype) GZZGTypes(@TypeOf(lst), Self) {
            const SCMTuple = std.meta.Tuple(&[1]type{guile.SCM} ** (lst.len + 1));
            var outlst: SCMTuple  = undefined;
            
            inline for (lst, 0..) |scm, idx| outlst[idx] = scm.s;
            outlst[lst.len] = guile.SCM_UNDEFINED;
            
            return .{ .s = @call(.auto, guile.scm_list_n, outlst) };
        }
        
        pub fn copy   (a: Self)          Self  { return .{ .s = guile.scm_list_copy(a.s) }; }
        pub fn append (a: Self, b: Self) Self  { return .{ .s = guile.scm_append(ListOf(Self).init(.{ a, b }).s) }; }
        //todo: check is this working?
        pub fn appendX(a: Self, b: Self) void  { _ = guile.scm_append_x(ListOf(Self).init(.{ a, b }).s); }
        //todo: type check
        pub fn cons   (a: Self, b: T)    Self  { return .{ .s = guile.scm_cons(b.s, a.s) }; }
        pub fn reverse(a: Self)          Self  { return .{ .s = guile.scm_reverse(a.s) }; }
        // pub fn reverseX(a: *List, newtail: Any) void { 
        
        pub fn ref    (a: Self, idx: Number) T { return .{ .s = guile.scm_list_ref(a.s, idx.s) }; }
        // list-tail
        // list-head

        // §6.6.9.6 List Modification
        //list-set!
        //list-cdr-set!
        pub fn delq  (a: Self, item: T) Self { return .{ .s = guile.scm_delq(item.s, a.s) }; }
        pub fn delv  (a: Self, item: T) Self { return .{ .s = guile.scm_delv(item.s, a.s) }; }
        pub fn delete(a: Self, item: T) Self { return .{ .s = guile.scm_delete(item.s, a.s) }; }
        
        pub fn delqX  (a: Self, item: T) void { _ = guile.scm_delq_x(item.s, a.s); }
        pub fn delvX  (a: Self, item: T) void { _ = guile.scm_delv_x(item.s, a.s); }
        pub fn deleteX(a: Self, item: T) void { _ = guile.scm_delete_x(item.s, a.s); }

        // todo: check
        pub fn delq1X  (a: Self, item: T) void { _ = guile.scm_delq1_x(item.s, a.s); }
        pub fn delv1X  (a: Self, item: T) void { _ = guile.scm_delv1_x(item.s, a.s); }
        pub fn delete1X(a: Self, item: T) void { _ = guile.scm_delete1_x(item.s, a.s); }
        //filter

        // §6.6.9.7 List Searching
        pub fn memq  (_: Self, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}
        pub fn memv  (_: Self, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}
        pub fn member(_: Self, _: anytype) gzzg.UnionSCM(.{Boolean, Any}) {@panic("Unimplemented");}
        
        //pub fn map(proc: Any, lists
        
        pub fn iterator(a: Self) ConstListIterator {
            return .{
                .head = a,
                .l = a
            };
        }

        pub const ConstListIterator = struct {
            head: Self,
            l: Self,
            
            pub fn next(self: *@This()) ?T {
                if (self.l.isNull().toZ()) {
                    return null;
                } else {
                    defer self.l = .{ .s = guile.scm_cdr(self.l.s) };
                    
                    return .{ .s = guile.scm_car(self.l.s) };
                }
            }
            
            pub fn peek(self: *@This()) ?T {
                if (self.l.isNull().toZ()) {
                    return null;
                } else {
                    return .{ .s = guile.scm_car(self.l.s) };
                }
            }
            
            pub fn reset(self: *@This()) void {
                self.l = self.head;
            }
        };
    };
}

//                                     -------------------------
//                                     Association Lists §6.6.20
//                                     -------------------------

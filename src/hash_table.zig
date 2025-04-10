// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const UnionSCM = gzzg.UnionSCM;

const GZZGTypes = gzzg.contracts.GZZGTypes;
const GZZGTupleOfTypes = gzzg.contracts.GZZGTupleOfTypes;

const Any       = gzzg.Any;
const Boolean   = gzzg.Boolean;
const Integer   = gzzg.Integer;
const List      = gzzg.List;
const PairOf    = gzzg.PairOf;
const Procedure = gzzg.Procedure;


pub fn HashTableOf(comptime K: type, comptime V: type) GZZGTupleOfTypes(.{ K, V }, type) {
    return struct {
        s: guile.SCM,

        pub const guile_name = "hash-table";
        const Self = @This();
        pub const Child = .{ K, V };


        pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_hash_table_p(a) }; }
        pub fn isZ(a: guile.SCM) bool { is(a).toZ(); }
        pub fn lowerZ(a: Self) Any { return .{ .s = a.s }; }

        // * DONE 6.6.22.2 Hash Table Reference                  :complete:allFunctions:
        // 
        
        pub fn clearX(a: Self) void { _ = guile.scm_hash_clear_x(a.s); }

        pub fn ref(a: Self, key: K, dflt: anytype) UnionSCM(.{ V, @TypeOf(dflt)}) {
            return .{ .s = guile.scm_hash_ref(a.s, key.s, dflt.s) };
        } 
        pub fn refQ(a: Self, key: K, dflt: anytype) UnionSCM(.{ V, @TypeOf(dflt)}) {
            return .{ .s = guile.scm_hashq_ref(a.s, key.s, dflt.s) };
        } 
        pub fn refV(a: Self, key: K, dflt: anytype) UnionSCM(.{ V, @TypeOf(dflt)}) {
            return .{ .s = guile.scm_hashv_ref(a.s, key.s, dflt.s) };
        }
        // scm_hashx_ref
        
        pub fn setX(a: Self, key: K,  value: V) void { _ = guile.scm_hash_set_x (a.s, key.s, value.s); } 
        pub fn setQX(a: Self, key: K, value: V) void { _ = guile.scm_hashq_set_x(a.s, key.s, value.s); } 
        pub fn setVX(a: Self, key: K, value: V) void { _ = guile.scm_hashv_set_x(a.s, key.s, value.s); } 
        // scm_hashx_set_x

        pub fn removeX (a: Self, key: K) void { _ = guile.scm_hash_remove_x(a.s, key.s); } 
        pub fn removeQX(a: Self, key: K) void { _ = guile.scm_hash_remove_x(a.s, key.s); }
        pub fn removeVX(a: Self, key: K) void { _ = guile.scm_hash_remove_x(a.s, key.s); }
        // scm_hashx_remove_x

        pub fn hash (key: K, size: Integer) Integer { return .{ .s = guile.scm_hash (key.s, size.s) }; }
        pub fn hashQ(key: K, size: Integer) Integer { return .{ .s = guile.scm_hashq(key.s, size.s) }; }
        pub fn hashV(key: K, size: Integer) Integer { return .{ .s = guile.scm_hashv(key.s, size.s) }; }

        pub fn getHandle(a: Self, key: K) UnionSCM(.{PairOf(K, V), Boolean}) {
            return .{ .s = guile.scm_hash_get_handle(a.s, key.s) };
        }  
        pub fn getHandleQ(a: Self, key: K) UnionSCM(.{PairOf(K, V), Boolean}) {
            return .{ .s = guile.scm_hashq_get_handle(a.s, key.s) };
        }
        pub fn getHandleV(a: Self, key: K) UnionSCM(.{PairOf(K, V), Boolean}) {
            return .{ .s = guile.scm_hashv_get_handle(a.s, key.s) };
        }      
        // scm_hashx_get_handle (hash, assoc, table, key)
        
        pub fn createHandleX(a: Self, key: K, init: V) UnionSCM(.{PairOf(K, V), Boolean}) {
             return .{ .s = guile.scm_hash_create_handle_x(a.s, key.s, init.s) };
        }
        pub fn createHandleQX(a: Self, key: K, init: V) UnionSCM(.{PairOf(K, V), Boolean}) {
             return .{ .s = guile.scm_hashq_create_handle_x(a.s, key.s, init.s) };
        }
        pub fn createHandleVX(a: Self, key: K, init: V) UnionSCM(.{PairOf(K, V), Boolean}) {
             return .{ .s = guile.scm_hashV_create_handle_x(a.s, key.s, init.s) };
        }
        // scm_hashx_create_handle_x (hash, assoc, table, key, init)

        //todo: generic Procedure types
        pub fn mapToList(a: Self, p: Procedure)            List    { return .{ .s = guile.scm_hash_map_to_list(p.s, a.s) }; }
        pub fn forEach  (a: Self, p: Procedure)            void    { _ = guile.scm_hash_for_each(p.s, a.s); }
        pub fn hashForEachHandle(a: Self, p: Procedure)    void    { _ = guile.scm_hash_for_each_handle(p.s, a.s); }
        pub fn fold     (a: Self, p: Procedure, init: Any) Any     { return .{ .s = guile.scm_hash_fold(p.s, init.s, a.s) }; }
        pub fn hashCount(a: Self, predicate: Procedure)    Integer { return .{ .s = guile.scm_hash_count(a.s, predicate.s) }; }
    };      
}           
            

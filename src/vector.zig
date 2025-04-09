// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const GZZGType = gzzg.contracts.GZZGType;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const Integer = gzzg.Integer;
const ListOf  = gzzg.ListOf;

//                                         --------------
//                                         Vector §6.6.10
//                                         --------------

pub fn VectorOf(comptime T: type) GZZGType(T, type) {
    return struct {
        s: guile.SCM,
        
        pub const guile_name = "vector";
        const Self = @This();
        pub const Child = T;
        
        pub fn fromList(l: ListOf(T)) Self { return .{ .s = guile.scm_vector(l.s) }; }
        pub fn make (length: Integer, fill: ?T) Self { return .{ .s = guile.scm_make_vector  (length.s, gzzg.orUndefined(fill)) }; }
        pub fn makeZ(length: usize,   fill: ?T) Self { return .{ .s = guile.scm_c_make_vector(length, gzzg.orUndefined(fill)) }; }

        pub fn toList(a: Self) ListOf(T) { return .{ .s = guile.scm_vector_to_list(a.s) }; }
     
        pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_vector_p(a) }; }
        pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_vector(a) != 0; }
        pub fn lowerZ(a: Self) Any { return .{ .s = a.s }; }

        // * DONE 6.6.10.3 Accessing and Modifying Vector Contents :complete:allFunctions:
        // 
        
        pub fn len (a: Self) Integer { return .{ .s = guile.scm_vector_length(a.s) }; }
        // pub fn lenZ(a: Self) usize  { return guile.SCM_SIMPLE_VECTOR_LENGTH(a.s); } // fix: broken
        
        pub fn ref(a: Self, idx: Integer) T { return .{ .s = guile.scm_vector_ref(a.s, idx.s) }; }
        //pub fn refZ(a: Self, idx: usize)  Any { return .{ .s = guile.SCM_SIMPLE_VECTOR_REF(a.s, idx) }; } // fix: broken
        
        pub fn setX (a: Self, idx: Integer, obj: T) void { _ = guile.scm_vector_set_x(a.s, idx.s, obj.s); }
        pub fn setXZ(a: Self, idx: usize,  obj:  T) void { _ = guile.scm_c_vector_set_x(a.s, idx, obj.s); }
        
        pub fn fillX(a: Self, fill: T) void { _ = guile.scm_vector_fill_x(a.s, fill.s); }
        pub fn copy (a: Self) Self { return .{ .s = guile.scm_vector_copy(a.s) }; }
        pub fn moveLeftX(v1: Self, start1: Integer, end1: Integer, v2: Self, start2: Integer) void {
            _ = guile.scm_vector_move_left_x(v1.s, start1.s, end1.s, v2.s, start2.s);
        }
        pub fn moveRightX(v1: Self, start1: Integer, end1: Integer, v2: Self, start2: Integer) void {
            _ = guile.scm_vector_move_right_x(v1.s, start1.s, end1.s, v2.s, start2.s);
        }
     
        // * DONE 6.6.10.4 Vector Accessing from C               :complete:allFunctions:
        // 

        pub fn iterator(a: Self) ConstIterator {
            var itr: ConstIterator = undefined;
            
            itr.elt = guile.scm_vector_elements(a.s, &itr.handle, &itr.len, &itr.ptr_inc);
            itr.idx = 0;
            
            return itr;
        }

        pub fn iteratorWritable(a: Self) Iterator {
            var itr: Iterator = undefined;
            
            itr.elt = guile.scm_vector_writable_elements(a.s, &itr.handle, &itr.len, &itr.ptr_inc);
            itr.idx = 0;
            
            return itr;
        }
        
        comptime {
            _ = gzzg.contracts.GZZGType(@This(), void);
        }
        
        // todo: deduplicate iterators if possible
        pub const Iterator = struct {
            handle: guile.scm_t_array_handle,
            len: usize,
            ptr_inc: isize,
            elt: [*]guile.SCM,
            
            idx: usize,
            
            const SelfItr = @This();
            
            pub fn next(self: *SelfItr) ?*T {
                if (self.idx >= self.len) return null;
                
                self.idx += 1;
                // zig doesn't allow negative ptr math. Workarouond many-item ptr.
                defer if (self.ptr_inc > 0) {
                    self.elt += @as(usize, @intCast(self.ptr_inc));
                } else {
                    self.elt -= @as(usize, @intCast(self.ptr_inc * -1));
                };
                
                return @ptrCast(self.elt);
            }
            
            pub fn peek(self: *SelfItr) ?*T {
                return if (self.idx >= self.len) null else @ptrCast(self.elt);
            }
            
            //pub fn rest(self: *Self)  []Any
            
            pub fn reset(self: *SelfItr) void {
                if (self.ptr_inc > 0) {
                    self.elt -= @as(usize, @intCast(self.ptr_inc)) * self.idx;
                } else {
                    self.elt += @as(usize, @intCast(self.ptr_inc * -1)) * self.idx;
                }
                
                self.idx = 0;
            }
            
            pub fn close(self: *SelfItr) void {
                guile.scm_array_handle_release(&self.handle);
            }
        };

        pub const ConstIterator = struct {
            handle: guile.scm_t_array_handle,
            len: usize,
            ptr_inc: isize,
            elt: [*]const guile.SCM,
            
            idx: usize,

            const SelfItr = @This();
            
            pub fn next(self: *SelfItr) ?T {
                if (self.idx >= self.len) return null;
                
                self.idx += 1;
                // zig doesn't allow negative ptr math. Workarouond many-item ptr.
                defer if (self.ptr_inc > 0) {
                    self.elt += @as(usize, @intCast(self.ptr_inc));
                } else {
                    self.elt -= @as(usize, @intCast(self.ptr_inc * -1));
                };
                
                return .{ .s = self.elt[0] };
            }

            pub fn peek(self: *SelfItr) ?T {
                return if (self.idx >= self.len) null else .{ .s = self.elt[0] };
            }

            pub fn reset(self: *SelfItr) void {
                if (self.ptr_inc > 0) {
                    self.elt -= @as(usize, @intCast(self.ptr_inc)) * self.idx;
                } else {
                    self.elt += @as(usize, @intCast(self.ptr_inc * -1)) * self.idx;
                }
                
                self.idx = 0;
            }

            pub fn close(self: *SelfItr) void {
                guile.scm_array_handle_release(&self.handle);
            }
        };
    };
}

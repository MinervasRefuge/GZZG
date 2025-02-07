// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const List = gzzg.List;
const Number = gzzg.Number;

//                                         --------------
//                                         Vector §6.6.10
//                                         --------------

pub const Vector = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_vector_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return guile.scm_is_vector(a) != 0; }

    pub fn lowerZ(a: Vector) Any { return .{ .s = a.s }; }

    pub fn fromList(a: List) Vector { return .{ .s = guile.scm_vector_to_list(a.s) }; }
    //todo: vector->list

    pub fn init (length: Number, fill: ?Any) Vector { return .{ .s = guile.scm_make_vector  (length.s, gzzg.orUndefined(fill)) }; }
    pub fn initZ(length: usize,  fill: ?Any) Vector { return .{ .s = guile.scm_c_make_vector(length, gzzg.orUndefined(fill)) }; }

    pub fn len (a: Vector) Number { return .{ .s = guile.scm_vector_length(a.s) }; }
    pub fn lenZ(a: Vector) usize  { return guile.SCM_SIMPLE_VECTOR_LENGTH(a.s); }

    pub fn refE(a: Vector, idx: Number) Any { return .{ .s = guile.scm_vector_ref(a.s, idx.s) }; }
    pub fn refZ(a: Vector, idx: usize)  Any { return .{ .s = guile.SCM_SIMPLE_VECTOR_REF(a.s, idx) }; }

    pub fn setEX (a: Vector, idx: Number, obj: Any) void { _ = guile.scm_vector_set_x(a.s, idx.s, obj.s); }
    pub fn setEXZ(a: Vector, idx: usize,  obj: Any) void { _ = guile.scm_c_vector_set_x(a.s, idx, obj.s); }

    //vector-fill
    pub fn copy(a: Vector) Vector { return .{ .s = guile.scm_vector_copy(a.s) }; }
    //vector-copy!
    //vector-move-left!
    //vector-move-right!

    pub fn iterator(a: Vector) ConstVectorIterator {
        var itr: ConstVectorIterator = undefined;

        itr.elt = guile.scm_vector_elements(a.s, &itr.handle, &itr.len, &itr.ptr_inc);
        itr.idx = 0;

        return itr;
    }



    // zig fmt: on
};

pub const ConstVectorIterator = struct {
    handle: guile.scm_t_array_handle,
    len: usize,
    ptr_inc: isize,
    elt: *const guile.SCM,

    idx: usize,

    const Self = @This();

    pub fn next(self: *Self) ?Any {
        if (self.idx >= self.len) return null;

        self.idx += 1;
        // zig doesn't allow negative ptr math. So work with it raw.
        const offset = @sizeOf(guile.SCM) * self.ptr_inc;
        defer if (offset > 0) {
            self.elt = @ptrFromInt(@intFromPtr(self.elt) + @as(usize, @intCast(offset)));
        } else {
            self.elt = @ptrFromInt(@intFromPtr(self.elt) - @as(usize, @intCast(offset * -1)));
        };

        return .{ .s = self.elt.* };
    }

    pub fn peek(self: *Self) ?Any {
        return if (self.idx >= self.len) null else .{ .s = self.elt.* };
    }

    //pub fn rest(self: *Self)  []Any

    pub fn reset(self: *Self) void {
        const offset = @sizeOf(guile.SCM) * self.ptr_inc;
        if (offset > 0) {
            self.elt = @ptrFromInt(@intFromPtr(self.elt) - (@as(usize, @intCast(offset)) * self.idx));
        } else {
            self.elt = @ptrFromInt(@intFromPtr(self.elt) + (@as(usize, @intCast(offset * -1)) * self.idx));
        }

        self.idx = 0;
    }

    pub fn close(self: *Self) void {
        guile.scm_array_handle_release(&self.handle);
    }
};

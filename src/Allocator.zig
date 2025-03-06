// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const guile = @import("guile");

const Alignment = std.mem.Alignment;
const Self = @This();

what: [:0]const u8,
// todo: consider if it was a single threaded application. could it be worth creating a stack of `whats` that can
// scoped to give more context?

pub fn allocator(self: *Self) std.mem.Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}

fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    const self: *Self = @alignCast(@ptrCast(ctx));
    _ = ret_addr;

    switch (alignment.order(.@"8")) {
        .gt, .eq => {},
        .lt => return null, // libguile/scm.h:228
    }

    return @ptrCast(guile.scm_gc_malloc(len, self.what));
}

fn resize(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
    const self: *Self = @alignCast(@ptrCast(context));
    _ = alignment;
    _ = ret_addr;

    _ = guile.scm_gc_realloc(memory.ptr, memory.len, new_len, self.what);
    @panic("Resize not implemented");
    //todo: fix and check resize alloc op.
    //return true;
}

fn remap(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = context;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = ret_addr;
    @panic("Unimplemented");
}

fn free(context: *anyopaque, buf: []u8, alignment: Alignment, ret_addr: usize) void {
    const self: *Self = @alignCast(@ptrCast(context));
    _ = alignment;
    _ = ret_addr;

    guile.scm_gc_free(buf.ptr, buf.len, self.what);
}

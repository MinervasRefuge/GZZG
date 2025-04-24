// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std                 = @import("std");
const gzzg                = @import("../gzzg.zig");
const guile               = gzzg.guile;
const iw                  = @import("../internal_workings.zig");

const Padding             = iw.Padding;
const assertTagSize       = iw.assertTagSize;

pub const Layout = extern struct {
    const Self = @This();
    
    tag: Tag,
    len: usize,
    contents: [*c]u8,
    parent: iw.SCM,

    const Tag = packed struct {
        tc7: iw.TC7,
        _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7)) = .nil,

        // #define SCM_F_BYTEVECTOR_CONTIGUOUS 0x100UL
        // #define SCM_F_BYTEVECTOR_IMMUTABLE 0x200UL
        // #define SCM_BYTEVECTOR_ELEMENT_TYPE(_bv)  (SCM_BYTEVECTOR_FLAGS (_bv) & 0xffUL)
        // #define SCM_BYTEVECTOR_TYPE_SIZE(var)  (scm_i_array_element_type_sizes[SCM_BYTEVECTOR_ELEMENT_TYPE (var)]/8)
        // #define SCM_BYTEVECTOR_TYPED_LENGTH(var) (SCM_BYTEVECTOR_LENGTH (var) / SCM_BYTEVECTOR_TYPE_SIZE (var))
        
        pub fn init() @This() {
            return .{
                .tc7 = .bytevector,
            };
        }
        
        comptime { assertTagSize(@This()); }
    };

    pub fn getContentsU8(self: *align(8) Self) []u8 {
        return self.contents[0..self.len];
    }

    pub fn getContents(self: *align(8) Self, comptime C: type) []C {
        switch (@typeInfo(C)) {
            .int, .float => {},
            else => @compileError("Not a number type: " ++ @typeName(C)),
        }

        // does it check that the lengths are multiples of and length check?
        return @ptrCast(self.getContentsU8()); 
    }

    comptime {
        
        // todo: guile.SCM_BYTEVECTOR_HEADER_SIZE is the number of fields. use it as a check
    }
};

// #define SCM_BYTEVECTOR_HEADER_SIZE   4U
// 
// #define SCM_BYTEVECTOR_LENGTH(_bv)  \
//   ((size_t) SCM_CELL_WORD_1 (_bv))
// #define SCM_BYTEVECTOR_CONTENTS(_bv)  \
//   ((signed char *) SCM_CELL_WORD_2 (_bv))
// #define SCM_BYTEVECTOR_PARENT(_bv)  \
//   (SCM_CELL_OBJECT_3 (_bv))


// /* Bytevector type.  */
// 
// #define SCM_BYTEVECTOR_HEADER_BYTES  \
//   (SCM_BYTEVECTOR_HEADER_SIZE * sizeof (scm_t_bits))
// 
// #define SCM_BYTEVECTOR_SET_FLAG(bv, flag) \
//   SCM_SET_BYTEVECTOR_FLAGS ((bv), SCM_BYTEVECTOR_FLAGS (bv) | flag)
// #define SCM_BYTEVECTOR_SET_LENGTH(_bv, _len)            \
//   SCM_SET_CELL_WORD_1 ((_bv), (scm_t_bits) (_len))
// #define SCM_BYTEVECTOR_SET_CONTENTS(_bv, _contents) \
//   SCM_SET_CELL_WORD_2 ((_bv), (scm_t_bits) (_contents))
// #define SCM_BYTEVECTOR_SET_PARENT(_bv, _parent) \
//   SCM_SET_CELL_OBJECT_3 ((_bv), (_parent))

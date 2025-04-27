// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

//! Contains a parallel implementation of guile scm bit un/packing C macros
//! Based on libguile/scm.h

const std   = @import("std");
const guile = @import("gzzg.zig").guile;
const bopts = @import("build_options");

/// represents a tagged ptr item.
pub const SCM      = *anyopaque; // libguile/scm.h:228
/// represents an untagged ptr to cells
pub const SCMCells = [*]align(8) SCM;
pub const SCMBits  = usize;

pub fn assertSCM(comptime Maybe: type) void {
    switch (Maybe) {
        guile.SCM,
        SCMCells,
        SCM => {},
        else => @compileError("Not A SCM type: " ++ @typeName(Maybe)),
    }
}

// needed as `*align(⍰) ⍰` can become `*anyopaque`
pub fn assertTagged(comptime Maybe: type) void {
    switch (Maybe) {
        guile.SCM,
        SCM => {},
        else => @compileError("Not a tagged SCM type: " ++ @typeName(Maybe)),
    }
}

// fn assertUntagged(comptime Maybe: type) void {
//     switch (Maybe) {
//         guile.SCM,
//         SCMCells => {},
//         else => @compileError("Not an untagged SCM type: " ++ @typeName(Maybe)),
//     }
// }

pub fn untagSCM(s: anytype) SCMCells {
    assertTagged(@TypeOf(s));
    const tc3_mask: usize = std.math.maxInt(std.meta.Tag(TC3)); 
    return @ptrFromInt(@intFromPtr(s) & ~tc3_mask);
}

pub fn tagSCM(s: SCMCells, tc3: TC3) SCM {
    return @ptrFromInt(@intFromPtr(s) | @intFromEnum(tc3));
}

/// returns a ptr to a struct containing an `untag` fn returning *align(8) T
pub fn TaggedPtr(T: type) type {
    return *struct {
        pub fn untag(self: *@This()) *align(8) T {
            const s: SCM = @ptrCast(self);
            return @ptrCast(untagSCM(s));
        }

        pub fn scm(self: *@This()) SCM {
            return @ptrCast(self);
        }
    };
}

comptime {
    const assert = std.debug.assert;
    
    assert(@sizeOf(guile.SCM) == @sizeOf(SCM));
    
    // libguile/scm.h:85
    assert(@sizeOf(SCM) >= 4);
    assert(@sizeOf(SCMBits) >= 4);

    assert(@sizeOf(SCMBits) >= @sizeOf(*anyopaque));
    assert(@sizeOf(SCM) >= @sizeOf(*anyopaque));
    //SCMBits must be a power of 2

    assert(@sizeOf(SCMBits) <= @sizeOf(*anyopaque));
    assert(@sizeOf(SCM) <= @sizeOf(*anyopaque));
}

pub fn isImmediate(scm: anytype) bool {
    assertTagged(@TypeOf(scm));
    return @intFromPtr(scm) & 0b110 != 0;
}

//
// TC => Type Code <n> (stored in the /n/ least significant bits)

fn checkTagValues(comptime E: type, comptime index: anytype) void {
    // check that the enum value match the value specified by guile.
    
    for (index) |entry| {
        if (@field(guile, @tagName(entry[0])) != @intFromEnum(@field(E, @tagName(entry[1])))) {
            @compileError("tag value wrong: " ++ @tagName(entry[0]));
        }
    }
}

pub const TC1 = enum (u1) {
    scm_object,
    invalid
};

pub const TC2 = enum (u2) {
    heap_or_nonint_immediate,
    invalid,
    small_integer,
    invalid2
};

pub const TC3 = enum(u3) {
    cons,      // 0b000: heap obj
    @"struct", // 0b001: struct / class instance
    int1,      // 0b010: small ints - even
    unused,    // 0b011: closure?
    imm24,     // 0b100: used from bools, chars, & special types: TC8
    tc7,       // 0b101: heap types 1: TC7
    int2,      // 0b110: small ints - odd
    tc7_2,     // 0b111: heap types 2: TC7

    comptime {
        checkTagValues(@This(), .{
            .{ .scm_tc3_cons,   .cons      },
            .{ .scm_tc3_struct, .@"struct" },
            .{ .scm_tc3_int_1,  .int1      },
            .{ .scm_tc3_unused, .unused    },  
            .{ .scm_tc3_imm24,  .imm24     },
            .{ .scm_tc3_tc7_1,  .tc7       },
            .{ .scm_tc3_int_2,  .int2      },
            .{ .scm_tc3_tc7_2,  .tc7_2     },
        });
    }
};

pub const TC7 = enum(u7) {
    symbol        = 0b0000_101, // 0x05 
    variable      = 0b0000_111, // 0x07
    vector        = 0b0001_101, // 0x0d
    wvect         = 0b0001_111, // 0x0f
    string        = 0b0010_101, // 0x15
    number        = 0b0010_111, // 0x17
    hashtable     = 0b0011_101, // 0x1d
    pointer       = 0b0011_111, // 0x1f
    fluid         = 0b0100_101, // 0x25
    stringbuf     = 0b0100_111, // 0x27
    dynamic_state = 0b0101_101, // 0x2d
    frame         = 0b0101_111, // 0x2f
    keyword       = 0b0110_101, // 0x35
    atomic_box    = 0b0110_111, // 0x37
    syntax        = 0b0111_101, // 0x3d
    values        = 0b0111_111, // 0x3f
    program       = 0b1000_101, // 0x45
    vm_cont       = 0b1000_111, // 0x47
    bytevector    = 0b1001_101, // 0x4d
    unused_4f     = 0b1001_111, // 0x4f
    weak_set      = 0b1010_101, // 0x55
    weak_table    = 0b1010_111, // 0x57
    array         = 0b1011_101, // 0x5d
    bitvector     = 0b1011_111, // 0x5f
    unused_65     = 0b1100_101, // 0x65
    unused_67     = 0b1100_111, // 0x67
    unused_6d     = 0b1101_101, // 0x6d
    unused_6f     = 0b1101_111, // 0x6f
    unused_75     = 0b1110_101, // 0x75
    smob          = 0b1110_111, // 0x77
    port          = 0b1111_101, // 0x7d
    unused_7f     = 0b1111_111, // 0x7f
    //_,

    comptime {
        checkTagValues(@This(), .{
            .{ .scm_tc7_symbol,        .symbol        },
            .{ .scm_tc7_variable,      .variable      },
            .{ .scm_tc7_vector,        .vector        },
            .{ .scm_tc7_wvect,         .wvect         },
            .{ .scm_tc7_string,        .string        },
            .{ .scm_tc7_number,        .number        },
            .{ .scm_tc7_hashtable,     .hashtable     },
            .{ .scm_tc7_pointer,       .pointer       },
            .{ .scm_tc7_fluid,         .fluid         },
            .{ .scm_tc7_stringbuf,     .stringbuf     },
            .{ .scm_tc7_dynamic_state, .dynamic_state },
            .{ .scm_tc7_frame,         .frame         },
            .{ .scm_tc7_keyword,       .keyword       },
            .{ .scm_tc7_atomic_box,    .atomic_box    },
            .{ .scm_tc7_syntax,        .syntax        },
            .{ .scm_tc7_values,        .values        },
            .{ .scm_tc7_program,       .program       },
            .{ .scm_tc7_vm_cont,       .vm_cont       },
            .{ .scm_tc7_bytevector,    .bytevector    },
            .{ .scm_tc7_unused_4f,     .unused_4f     },
            .{ .scm_tc7_weak_set,      .weak_set      },
            .{ .scm_tc7_weak_table,    .weak_table    },
            .{ .scm_tc7_array,         .array         },
            .{ .scm_tc7_bitvector,     .bitvector     },
            .{ .scm_tc7_unused_65,     .unused_65     },
            .{ .scm_tc7_unused_67,     .unused_67     },
            .{ .scm_tc7_unused_6d,     .unused_6d     },
            .{ .scm_tc7_unused_6f,     .unused_6f     },
            .{ .scm_tc7_unused_75,     .unused_75     },
            .{ .scm_tc7_smob,          .smob          },
            .{ .scm_tc7_port,          .port          },
            .{ .scm_tc7_unused_7f,     .unused_7f     },
        });
    }
};

// immediates other than fixnums
pub const TC8  = enum (u8) {
    special_objects = 0b00000_100,
    characters      = 0b00001_100,
    unused0         = 0b00010_100,
    unused1         = 0b00011_100,
    _,

     comptime {
         checkTagValues(@This(), .{
             .{ .scm_tc8_flag,     .special_objects },
             .{ .scm_tc8_char,     .characters      },
             .{ .scm_tc8_unused_0, .unused0         },
             .{ .scm_tc8_unused_1, .unused1         },
         });
    }
};

//pub const TC16 = enum (u16) { //tc16 (for tc7==scm_tc7_smob):
//    _,
//};

pub fn getTCFor(comptime TC: type, scm: anytype) TC {
    assertTagged(@TypeOf(scm));
    const info = @typeInfo(TC).@"enum";
    return @enumFromInt(@as(info.tag_type, @truncate(@intFromPtr(scm))));
}

pub const GuileClassification = enum {
    array,        
    atomic_box,   
    bit_vector,        
    byte_vector,   
    character,
    dynamic_state,
    flags,
    fluid,        
    frame,        
    hashtable,    
    keyword,      
    number,
    pointer,      
    port,
    program,      
    smob,         
    special_object,
    string,              
    stringbuf,
    @"struct",
    symbol,       
    syntax,       
    values,       
    variable,     
    vector,       
    vm_continuation,      
    weak_set,     
    weak_table,   
    weak_vector,
    
    pub fn classify(a: anytype) GuileClassification {
        assertTagged(@TypeOf(a));
        
        if (getTCFor(TC2, a) == .small_integer) return .number;
        
        switch (getTCFor(TC3, a)) {
            .cons => {
                const cell0 = untagSCM(a)[0];

                switch(getTCFor(TC3, cell0)) {
                    .@"struct" => return .@"struct",
                    .tc7,
                    .tc7_2 => return switch (getTCFor(TC7, cell0)) {
                        .symbol        => .symbol,     
                        .variable      => .variable,
                        .vector        => .vector,       
                        .wvect         => .weak_vector,        
                        .string        => .string,       
                        .number        => .number,       
                        .hashtable     => .hashtable,    
                        .pointer       => .pointer,
                        .fluid         => .fluid,
                        .stringbuf     => .stringbuf,
                        .dynamic_state => .dynamic_state,
                        .frame         => .frame,
                        .keyword       => .keyword,
                        .atomic_box    => .atomic_box,
                        .syntax        => .syntax,
                        .values        => .values,
                        .program       => .program,
                        .vm_cont       => .vm_continuation,
                        .bytevector    => .byte_vector,
                        .weak_set      => .weak_set,
                        .weak_table    => .weak_table,
                        .array         => .array,
                        .bitvector     => .bit_vector,
                        .smob          => .smob,
                        .port          => .port,
                        else => @panic("Unknown heap type")
                    },
                    else => @panic("Unreachable type?"),
                }
            },
            .@"struct" => return .@"struct", // or probably a vtable
            // int1,      
            .unused => @panic("Shouldn't exist"),     
            .imm24 => {
                switch (getTCFor(TC8, a)) {
                    .special_objects => return .special_object,
                    .characters => return .character,
                    else => @panic("Shouldn't Exist")
                }
            },
            // tc7,       
            // int2,      
            // tc7_2,
            else => unreachable
        }
    }
};

pub const DebugHint = struct {
    s: SCM,

     pub fn format(v: @This(), comptime fmt: []const u8,
                   options: std.fmt.FormatOptions, writer: anytype) !void {
         _ = options;
         _ = fmt;

         const max = comptime init: {
             var lavg = 0;
             for (std.meta.fieldNames(GuileClassification)) |field_name| {
                 lavg += field_name.len;
             }

             break :init @divFloor(lavg, std.meta.fieldNames(GuileClassification).len);          
         };

         const classification = GuileClassification.classify(v.s);

         const cPrint = std.fmt.comptimePrint;
         const fmt_cname = cPrint("{{s: >{d}}}", .{max});
         const fmt_ptr   = cPrint("{{X:0>{d}}}", .{@sizeOf(*anyopaque) * 2});
         const fmt_disp  = cPrint("<{s}@{s}>", .{fmt_cname, fmt_ptr});
         
         try std.fmt.format(writer, fmt_disp, .{
             @tagName(classification),
             @intFromPtr(v.s),
         });
    }

    pub fn from(scm: anytype) @This() {
        assertTagged(@TypeOf(scm));

        return .{ .s = scm };
    }
};

//
//
//

//
// §7.6.2.21 (rnrs arithmetic fixnums) naming
pub const FixNum = std.meta.Int(.signed, @bitSizeOf(isize) - @bitSizeOf(TC2));
const UFixNum = std.meta.Int(.unsigned, @bitSizeOf(usize) - @bitSizeOf(TC2)); // used in internal casting

pub fn isFixNum(scm: anytype) bool {
    assertTagged(@TypeOf(scm));
    return getTCFor(TC2, scm) == .small_integer;
}
 
pub fn getFixNum(scm: anytype) FixNum {
    // which on?
    assertTagged(@TypeOf(scm)); // assertSCM(@TypeOf(scm));
    return @bitCast(@as(UFixNum, @truncate(@intFromPtr(scm) >> @bitSizeOf(TC2))));
}

pub fn makeFixNum(fx: FixNum) SCM {
    const gnum: UFixNum = @bitCast(fx); // signed -> unsigned
    const unum: usize = gnum; // widen type
    const scm = unum << @bitSizeOf(TC2) | @intFromEnum(TC2.small_integer); // tag
    
    return @ptrFromInt(scm);
}


//
//
//

/// size in bits
pub fn Padding(size: comptime_int) type {
    const T = std.builtin.Type;    
    
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.meta.Int(.unsigned, size),
            .fields = &[_]T.EnumField{.{.name = "nil", .value = 0}},
            .decls = &[_]T.Declaration{},
            .is_exhaustive = true,
        }
    });
}

//

pub const hash        = @import("internal_workings/hash.zig");
pub const string      = @import("internal_workings/string.zig");
pub const byte_vector = @import("internal_workings/byte_vector.zig");
pub const @"struct"   = @import("internal_workings/struct.zig");

pub const bytecode = @import("internal_workings/bytecode.zig");

test {
    @import("std").testing.refAllDecls(@This());
}


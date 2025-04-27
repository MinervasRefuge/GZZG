// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std                 = @import("std");
const gzzg                = @import("../gzzg.zig");
const guile               = gzzg.guile;
const iw                  = @import("../internal_workings.zig");
const Padding             = iw.Padding;
const assertTagSize       = iw.assertTagSize;
const TaggedPtr           = iw.TaggedPtr;

// WIP

pub const Layout = extern struct {
    vtable        : TaggedPtr(Layout),  // scm of tc3 struct
    layout        : iw.SCM, // symbol
    flags         : Flags,
    finaliser     : ?*const fn (iw.SCM) callconv(.c) void, // scm_t_struct_finalize
    printer       : iw.SCM, // #f or ?
    name          : iw.SCM, //gzzg.UnionOf(.{ gzzg.Boolean, gzzg.Symbol })  , // #f or Symbol
    size          : usize,  //iw.SCM, // usize ?
    unboxed_fields: iw.SCM, // [*c]u32 ?  /* Raw uint32_t* bitmask indicating unboxed fields.  */
    reserved      : iw.SCM, // = 0 // data set
    offset_user   : void,

    pub fn isBottom(s: iw.SCM) bool { // s = .cons and s[0] = struct
        if(!iw.isImmediate(s) and iw.getTCFor(iw.TC3, s) == .@"cons") {
            const cell0 = iw.getSCMCell(s, 0);        
            return !iw.isImmediate(cell0) and iw.getTCFor(iw.TC3, cell0) == .@"struct"; 
        }
    
        return false;
    }
        
    pub fn isBase(s: *align(8) Layout) bool {
        const scm: iw.SCM = @ptrCast(s);
        const maybe_base = iw.getSCMCell(scm, 0);
        std.debug.assert(iw.getTCFor(iw.TC3, maybe_base) == .@"struct");
        return scm == iw.untagSCM(maybe_base);
    }

    //pub fn isVTable(s

    // go up a programmers tree (to root)
    pub fn assend(self: *align(8) Layout) ?*align(8) Layout {
        if (self.isBase()) {
            return null;
        } else {
            return self.vtable.untag();
        }
    }

    pub fn format(v: @This(), comptime fmt: []const u8,
                  options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = options;
        _ = fmt;

        const red = "\x1B[31m";
        const green = "\x1B[32m";
        const off = "\x1B[0m";
        try std.fmt.format(
            writer,
            \\{s}{{{s}
            \\  {s}vtable{s}   : {}
            \\  {s}layout{s}   : {}
            \\  {s}flags{s}    : {}
            \\  {s}finaliser{s}: {*}
            \\  {s}printer{s}  : {}
            \\  {s}name{s}     : {}
            \\  {s}size{s}     : {d}
            \\  {s}unboxed_fields{s}: {*}
            \\  {s}reserved{s} : {*}
            \\{s}}}{s}
            , .{
            green, off,
            red, off, iw.SCMDebugHint{ .s = v.vtable },
            red, off, iw.SCMDebugHint{ .s = v.layout },
            red, off, v.flags,
            red, off, v.finaliser,
            red, off, iw.SCMDebugHint{ .s = v.printer },
            red, off, iw.SCMDebugHint{ .s = v.name },
            red, off, v.size,
            red, off, v.unboxed_fields,
            red, off, v.reserved,
            green, off,
        });
    }
    

    pub const Flags = packed struct(iw.SCMBits) {
        validated        : bool,
        vtable           : bool,
        applicable_vtable: bool,
        applicable       : bool,
        setter_vtable    : bool,
        setter           : bool,
        _reserved0       : bool,
        _reserved1       : bool,
        smob0            : bool,
        goops0           : bool,
        goops1           : bool,
        goops2           : bool,
        goops3           : bool,
        goops4           : bool,
        _reserved2       : bool,
        _reserved3       : bool,
        // user flag shift 16
        _padding_end: Padding(@bitSizeOf(iw.SCMBits) - 16) = .nil,
        
        comptime { assertTagSize(@This()); }
    };
    
    comptime {
        std.debug.assert(
            std.meta.fields(@This()).len - 2 ==
                @divExact(gzzg.guile.SCM_VTABLE_BASE_LAYOUT.len, 2)
        );

        // check that the index of the variables match the index specified by guile.
        const index = .{
            .{ .scm_vtable_index_layout           , .layout },
            .{ .scm_vtable_index_flags            , .flags },
            .{ .scm_vtable_index_instance_finalize, .finaliser },
            .{ .scm_vtable_index_instance_printer , .printer },
            .{ .scm_vtable_index_name             , .name },
            .{ .scm_vtable_index_size             , .size },
            .{ .scm_vtable_index_unboxed_fields   , .unboxed_fields },
            .{ .scm_vtable_index_reserved_7       , .reserved },
            // scm_vtable_offset_user
        };

        const field_names = std.meta.fieldNames(@This());
        for (index) |entry| {
            const idx = init: {
                for (field_names, 0..) |field_name, i| {
                    if (std.mem.eql(u8, field_name, @tagName(entry[1])))
                        break :init i;
                }

                @compileError("field not found: " ++ @tagName(entry[1]));
            };

            if (@field(guile, @tagName(entry[0])) + 1 != idx) {
                @compileError("vtable order wrong: " ++ @tagName(entry[0]));
            }
        }
    }
};

pub const LayoutCons = extern struct {
    vtable: TaggedPtr(Layout),
    slots: void,
    

};


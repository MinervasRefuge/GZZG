// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std            = @import("std");
const iw             = @import("../internal_workings.zig");
pub const encoding   = @import("string_encoding.zig");
const CharacterWidth = encoding.CharacterWidth;
const Padding        = iw.Padding;
const assertTagSize  = iw.assertTagSize;

//      |   TC7  |
//           |TC3|
// BA987 6543 210
// --------------
// 00010_0000_000 == Shared String     0x100
// 00100_0000_000 == Readonly String   0x200
// 01000_0000_000 == StringBuf Wide    0x400
// 10000_0000_000 == StringBuf Mutable 0x800

pub const Layout = extern struct {
    tag: Tag,
    buffer: extern union {
        strbuf: *align(8) Buffer(.ambiguous),
        shared: *align(8) Layout
    },
    start: usize,
    len: usize,

    const Tag = packed struct {
        tc7: iw.TC7,
        _padding1: Padding(1) = .nil,
        shared: bool,
        read_only: bool,
        _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7 + 1 + 1 + 1)) = .nil,
        
        pub fn init(is_shared: bool, is_read_only: bool) @This() {
            return .{
                .tc7 = .string,
                .shared = is_shared,
                .read_only = is_read_only
            };
        }
        
        comptime { assertTagSize(@This()); }
    };
};

pub const BufferSlice = union(encoding.CharacterWidth) {
    narrow: [:0]CharacterWidth.narrow.backingType(),
    wide: [:0]CharacterWidth.wide.backingType(),
};

pub const BufferOptions = union(enum) {
    ambiguous,
    fixed: struct {
        backing: CharacterWidth,
        len: comptime_int
    }, // consider runtime stringbuf option?
};

// should these pointer refs be an explicit align(8)

pub fn Buffer(options: BufferOptions) type {
    return extern struct{
        const Self = @This();
        
        tag: Tag,
        len: usize = 0,
        buffer: switch (options) {
            .ambiguous => void,
            .fixed => |f| [f.len:0] f.backing.backingType()
        } = undefined,

        pub const init = switch (options) {
            .ambiguous => @compileError("Can't instantiate ambiguous string buffer"), // really?
            .fixed => initFixed,
        };
        
        fn initFixed(str_utf8: []const u8) !@This() {
            const fixed = options.fixed;
            
            var sb = @This(){
                .tag = .init(fixed.backing, false),
            };
            
            const written = try fixed.backing.encode(str_utf8, &sb.buffer);
            sb.len = written;
            sb.buffer[sb.len] = 0;

            return sb;
        }

        pub const getSliceExact = switch (options) {
            .ambiguous => @compileError("Can't grab an exact slice of an ambiguous string buffer"),
            .fixed => |f| struct {
                fn getSliceExact(self: *Self) [:0]f.backing.backingType() {
                    return &self.buffer;
                }
            }.getSliceExact,
        };

        pub fn getSlice(self: *Self) BufferSlice {
            switch (options) {
                .ambiguous => {
                    return switch (self.tag.width) {
                        .wide => .{
                            .wide = @ptrCast(@as([*:0]CharacterWidth.wide.backingType(),
                                                 @ptrCast(&self.buffer))
                                                 [0..self.len])},
                        .narrow => .{
                            .narrow = @ptrCast(@as([*:0]CharacterWidth.narrow.backingType(),
                                                   @ptrCast(&self.buffer))
                                                   [0..self.len])},
                    };
                },
                .fixed => |f| {
                    return switch (f.backing) {
                        .wide => .{ .wide = &self.buffer },
                        .narrow => .{ .narrow = &self.buffer },
                    };
                },
            }
        }

        pub fn ambiguation(self: *Self) *Buffer(.ambiguous) {
            return @ptrCast(self);
        }

        pub const Tag = packed struct {
            tc7: iw.TC7,
            _padding1: Padding(3) = .nil,
            width: CharacterWidth,
            mutable: bool,
            _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7 + 3 + 1 + 1)) = .nil,
            
            pub fn init(char_width:CharacterWidth, is_mutable:bool) @This() {
                return .{
                    .tc7 = .stringbuf,
                    .width = char_width,
                    .mutable = is_mutable
                };
            }
            
            comptime { assertTagSize(@This()); }
        };
    };
}

pub fn BufferFrom(comptime str_utf8:[] const u8) type {
    const backing = encoding.CharacterWidth.fits(str_utf8)
        catch |err| @compileError(@errorName(err));
    const len_encoded = backing.lenIn(str_utf8);

    return Buffer(.{ .fixed = .{ .backing = backing, .len = len_encoded }});
}

pub inline fn staticBuffer(comptime str_utf8:[]const u8) BufferFrom(str_utf8) {
    @setEvalBranchQuota(10_000); // how big?
    comptime { // is this the best way to hint that this is a comptime only function?
        return BufferFrom(str_utf8).init(str_utf8) catch |err| @compileError(@errorName(err));
    }
}

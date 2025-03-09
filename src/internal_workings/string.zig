// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const iw    = @import("../internal_workings.zig");
pub const encoding = @import("string_encoding.zig");
const CharacterWidth = encoding.CharacterWidth;
const Padding = iw.Padding;
const assertTagSize = iw.assertTagSize;

//       TC7  TC3
// BA987 6543 210
// --------------
// 00010_0000_000  ==  Shared String      0x100
// 00100_0000_000  ==  Readonly String    0x200
// 01000_0000_000  ==  StringBuf wide     0x400
// 10000_0000_000  ==  StringBuf Mutable  0x800

pub const Layout = extern struct {
    tag: Tag,
    buffer: extern union {
        strbuf: *align(8) StringBufferUnknown,
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

const StringBufferSlice = union {
    narrow: [:0]CharacterWidth.narrow.backingType(),
    wide: [:0]CharacterWidth.wide.backingType(),
};

pub fn Buffer(len: comptime_int, comptime backing: CharacterWidth) type {
    return extern struct{
        tag: StringBufferUnknown.Tag,
        len: usize = 0,
        buffer: [len:0] backing.backingType() = undefined,

        pub fn init(str_utf8: []const u8) !@This() {     
            var sb = @This(){
                .tag = .init(backing, false),
            };
            
            const written = try backing.encode(str_utf8, &sb.buffer);
            sb.len = written;
            sb.buffer[sb.len] = 0;

            return sb;
        }

        pub fn getSliceExact(self: *@This()) [:0]backing.backingType() {
            return &self.buffer;
        }

        pub fn getSlice(self: *@This()) StringBufferSlice {
            return switch (backing) {
                .wide => .{ .wide = &self.buffer },
                .narrow => .{ .narrow = &self.buffer },
            };
        }


    };
}

pub const StringBufferUnknown = extern struct {
    tag: Tag,
    len: usize,
    buffer: u8,

    pub fn getSlice(self: *@This()) StringBufferSlice {
        return switch (self.tag.wide) {
            .wide => 
                .{ .wide = @ptrCast(@as([*:0]const CharacterWidth.wide.backingType(),
                                               @ptrCast(&self.buffer))
                                               [0..self.len])},
            .narrow =>
                .{ .narrow = @ptrCast(@as([*:0]const CharacterWidth.narrow.backingType(),
                                        @ptrCast(&self.buffer))
                                        [0..self.len])},
        };
    }

    pub const Tag = packed struct {
        tc7: iw.TC7,
        _padding1: Padding(3) = .nil,
        width: CharacterWidth,
        mutable: bool,
        
        _padding2: Padding(@bitSizeOf(iw.SCMBits) - (7 + 3 + 1 + 1)) = .nil,
        
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

pub fn StringBufferFrom(comptime str_utf8:[] const u8) type {
    const backing = encoding.CharacterWidth.fits(str_utf8)
        catch |err| @compileError(@errorName(err));
    const len_encoded = backing.lenIn(str_utf8);

    return Buffer(len_encoded, backing);
}

pub inline fn staticStringBuffer(comptime str_utf8:[] const u8) align(8) StringBufferFrom(str_utf8) {
    @setEvalBranchQuota(10_000); // how big?
    comptime { // is this the best way to hint that this is a comptime only function?
        return StringBufferFrom(str_utf8).init(str_utf8) catch |err| @compileError(@errorName(err));
    }
}

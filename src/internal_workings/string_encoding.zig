// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std = @import("std");
const Utf8View                    = std.unicode.Utf8View;
const utf8CodepointSequenceLength = std.unicode.utf8CodepointSequenceLength;
const utf8CountCodepoints         = std.unicode.utf8CountCodepoints;
const utf8Encode                  = std.unicode.utf8Encode;
const utf8EncodeComptime          = std.unicode.utf8EncodeComptime;


const UTF8Errors = error{
    InvalidUtf8,
    TruncatedInput,
    Utf8InvalidStartByte,
    Utf8DecodeError,
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8EncodesSurrogateHalf,
    Utf8CodepointTooLarge
};

// todo: Clean up unused fns

// Guile stringbufs are either...
// - narrow (Latin1)
// - wide (UCS-4/UTF-32)

pub const CharacterWidth = enum(u1) {
    const Self = @This();
    
    narrow = 0,
    wide = 1,

    pub fn fits(str_utf8: []const u8) error{InvalidUtf8}!Self {
        const view = try Utf8View.init(str_utf8);
        var iter = view.iterator();

        while (iter.nextCodepoint()) |codepoint| {
            if (codepoint > 0xFF)
                return .wide;
        }

        return .narrow;
    }

    pub fn backingType(comptime self: Self) type {
        return switch(self) {
            .narrow => u8,
            .wide => u32,
        };
    }

    pub fn lenIn(self: Self, str_utf8:[] const u8) !usize {
        return switch(self) {
            .narrow => Latin1.lenInLatin1(str_utf8), 
            .wide => UTF32.lenInUTF32(str_utf8),
        };
    }
    
    pub fn lenInComptime(self: Self, comptime str_utf8:[] const u8) usize {
        return switch(self) {
            .narrow => Latin1.lenInLatin1Comptime(str_utf8), 
            .wide => UTF32.lenInUTF32Comptime(str_utf8),
        };
    }

    pub fn encode(allocator: std.mem.Allocator, str_utf8:[]const u8) !BufferSlice {
        switch (try fits(str_utf8)) {
            inline else => |w| {
                const buffer = try allocator.alloc(w.backingType(),
                                                   1 + (w.lenIn(str_utf8) catch unreachable));
                const written =  w.encodeStatic(str_utf8, buffer) catch unreachable;
                std.debug.assert(written == buffer.len - 1);

                buffer[buffer.len-1] = 0;

                // todo: better way of going enum -> union field?
                return switch (w) {
                    .narrow => |nn| .{ .narrow = @as([:0]nn.backingType(), @ptrCast(buffer[0..buffer.len-1])) },
                    .wide => |ww| .{ .wide = @as([:0]ww.backingType(), @ptrCast(buffer[0..buffer.len-1]))},
                };
            },
        }
    }
    
    pub fn encodeStatic(comptime self: Self, str_utf8:[]const u8, str_encoded:[] self.backingType()) !usize {
        return switch (self) {
            .narrow => Latin1.toStr(str_utf8, str_encoded),
            .wide => UTF32.toStr(str_utf8, str_encoded)
        };
    }

    pub fn encodeComptime(comptime self: Self, comptime str_utf8:[]const u8) [self.lenInComptime(str_utf8):0] self.backingType() {
        return switch (self) {
            .narrow => Latin1.comptimeStr(str_utf8),
            .wide => UTF32.comptimeStr(str_utf8)
        };
    }

    pub const BufferSlice = union(Self) {
        narrow: [:0]Self.narrow.backingType(),
        wide: [:0]Self.wide.backingType(),
    };
};


pub const Latin1 = struct {
    // Latin1 (u8) is composed of the following Unicode Blocks,
    //  - C0
    //  - Basic Latin
    //  - C1
    //  - Latin-1 Supplement
    //
    // Same order and placement as Unicode
    
    pub fn detailsOfUTF8(str_latin1: []const u8) struct {usize, bool} {
        var len_utf8: usize = 0;
        var multibyte_utf8 = false;
        
        for (str_latin1) |char_latin1| {
            if (char_latin1 <= 0x7F) {
                len_utf8 += 1;
            } else {
                multibyte_utf8 = true;
                len_utf8 += 2;
            }
        }

        return .{ len_utf8, multibyte_utf8 };
    }
    
    pub fn lenOfUTF8(str_latin1: []const u8) usize {
        return detailsOfUTF8(str_latin1)[0];
    }

    pub fn isMultibyteUTF8(str_latin1: []const u8) bool {
        for (str_latin1) |char_latin1| {
            if (char_latin1 > 0x7F) return true;
        }

        return false;
    }
    
    pub fn writeToUTF8(str_latin1: []const u8, writer: anytype) @TypeOf(writer).Error!void {
        if (!isMultibyteUTF8(str_latin1)) {
            try writer.writeAll(str_latin1);
            return;
        }

        var str_utf8:[4] u8 = undefined;
        
        for (str_latin1) |codepoint| {
            // Neither Utf8CannotEncodeSurrogateHalf or CodepointTooLarge should ever happen.
            const bytes = utf8Encode(codepoint, &str_utf8) catch unreachable;
            try writer.writeAll(str_utf8[0..bytes]);
        }
    }

    pub fn toUTF8(allocator: std.mem.Allocator, str_latin1: []const u8) @TypeOf(allocator).Error![:0] u8 {
        const len_utf8, const multibyte_utf8 = detailsOfUTF8(str_latin1);
        const str_utf8 = try allocator.alloc(u8, len_utf8 + 1);

        if (!multibyte_utf8) {
            @memcpy(str_utf8[0..len_utf8], str_latin1);

            str_utf8[len_utf8] = 0;
            
            return @ptrCast(str_utf8[0..len_utf8]);
        }

        var pos_utf8: usize = 0;
        for (str_latin1) |codepoint| {
            // Neither Utf8CannotEncodeSurrogateHalf or CodepointTooLarge should ever happen.
            pos_utf8 += utf8Encode(codepoint, str_utf8[pos_utf8..]) catch unreachable;
        }

        std.debug.assert(pos_utf8 == len_utf8);
        
        str_utf8[len_utf8] = 0;

        return @ptrCast(str_utf8[0..len_utf8]);
    }
    
    pub fn lenInLatin1(str_utf8: []const u8) (error{NotLatin1Compatible} || UTF8Errors)!usize {
        const width = try CharacterWidth.fits(str_utf8);
        if (width == .wide)
            return error.NotLatin1Compatible;
        
        return utf8CountCodepoints(str_utf8);
    }
    
    pub inline fn lenInLatin1Comptime(comptime str_utf8: []const u8) comptime_int {
        comptime {
            const width = CharacterWidth.fits(str_utf8) catch |err| @compileError(@errorName(err));
            if (width == .wide)
                @compileError("Not a latin-1 compatable string");
            return utf8CountCodepoints(str_utf8) catch |err| @compileError(@errorName(err));
        }
    }
    
    pub fn comptimeStr(comptime str_utf8:[]const u8) [lenInLatin1Comptime(str_utf8):0] u8 {
        comptime {
            const len_latin1 = lenInLatin1Comptime(str_utf8);
            var str_latin1: [len_latin1:0] u8 = undefined;
            
            const view = Utf8View.initComptime(str_utf8);
            var iter = view.iterator();
            var pos_latin1:usize = 0;

            @setEvalBranchQuota(100000);
            while (iter.nextCodepoint()) |codepoint| {
                if (codepoint > 0xFF)
                    @compileError("Unicode doesn't fit inside Latin-1: " ++
                                      utf8EncodeComptime(codepoint));
                
                str_latin1[pos_latin1] = @truncate(codepoint);
                pos_latin1 += 1;
            }
            
            if (pos_latin1 != len_latin1)
                @compileError("Oh no");
            
            return str_latin1;
        }
    }

    pub fn toStr(str_utf8:[]const u8, str_latin1:[] u8) error{InvalidUtf8, NotLatin1Compatible, NoSpaceLeft}!usize {
        const view = try Utf8View.init(str_utf8);
        var iter = view.iterator();
        var pos_latin1:usize = 0;
        
        while (iter.nextCodepoint()) |codepoint| {
            if (pos_latin1 >= str_latin1.len)
                return error.NoSpaceLeft;
            
            if (codepoint > 0xFF)
                return error.NotLatin1Compatible;
            
            str_latin1[pos_latin1] = @truncate(codepoint);
            pos_latin1 += 1;
        }
        
        return pos_latin1;
    }
};


pub const UTF32 = struct {    
    pub const replacement_character = utf8EncodeComptime(std.unicode.replacement_character);
    
    pub fn writeToUTF8(str_utf32: []const u32, writer: anytype) @TypeOf(writer).Error!void {
        var str_utf8:[4] u8 = undefined;
        
        for (str_utf32) |codepoint| {            
            try writer.writeAll(if (utf8Encode(@truncate(codepoint), &str_utf8))
                                    |bytes| str_utf8[0..bytes]
                                else
                                    |_| &replacement_character);
        }
    }

    pub fn lenInUTF8(str_utf32: [] const u32) !usize {
        var len_utf8:usize = 0;

        for (str_utf32) |codepoint| {
            len_utf8 += try utf8CodepointSequenceLength(@truncate(codepoint));
        }

        return len_utf8;
    }
    
    pub fn toUTF8(allocator: std.mem.Allocator, str_utf32: []const u32)  ![:0] u8 {
        const len_utf8 = try lenInUTF8(str_utf32);
        const str_utf8 = try allocator.alloc(u8, len_utf8 + 1);

        var pos_utf8: usize = 0;
        for (str_utf32) |codepoint| {
            pos_utf8 += try utf8Encode(@truncate(codepoint), str_utf8[pos_utf8..]);
        }

        str_utf8[len_utf8] = 0;

        std.debug.assert(pos_utf8 == len_utf8);

        return @ptrCast(str_utf8[0..len_utf8]);
        
    }

    pub fn lenInUTF32(str_utf8: []const u8) !usize {
        return utf8CountCodepoints(str_utf8);
    }
    
    pub inline fn lenInUTF32Comptime(comptime str_utf8: [] const u8) comptime_int {
        return comptime utf8CountCodepoints(str_utf8) catch |err| @compileError(@errorName(err));
    }
    
    pub fn comptimeStr(comptime str_utf8: [] const u8) [lenInUTF32Comptime(str_utf8):0] u32 {
        const len_utf32 = lenInUTF32Comptime(str_utf8);
        var str_utf32: [len_utf32:0] u32 = undefined;
    
        const view = Utf8View.initComptime(str_utf8);
        var iter = view.iterator();
        var pos_utf32 = 0;
        
        while (iter.nextCodepoint()) |codepoint| {
            str_utf32[pos_utf32] = codepoint;
            pos_utf32 += 1;
        }
    
        if (pos_utf32 != len_utf32)
            @compileError("Oh no");
    
        return str_utf32;
    }

    pub fn toStr(str_utf8:[]const u8, str_utf32:[] u32) error{InvalidUtf8, NoSpaceLeft}!usize {
        const view = try Utf8View.init(str_utf8);
        var iter = view.iterator();
        var pos_utf32:usize = 0;
        
        while (iter.nextCodepoint()) |codepoint| {
            if (pos_utf32 >= str_utf32.len)
                return error.NoSpaceLeft;
            
            str_utf32[pos_utf32] = codepoint;
            pos_utf32 += 1;
        }

        return pos_utf32;
    }
};

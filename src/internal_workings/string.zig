// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std                 = @import("std");
const gzzg                = @import("../gzzg.zig");
const iw                  = @import("../internal_workings.zig");
pub const encoding        = @import("string_encoding.zig");
const CharacterWidth      = encoding.CharacterWidth;
const BufferSlice         = encoding.CharacterWidth.BufferSlice;
const BufferSliceSentinel = encoding.CharacterWidth.BufferSliceSentinel;
const Padding             = iw.Padding;

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

    // todo: should buffer be anytype?
    // is buffer a *const or depended on StringBuf flags
    pub fn init(buffer: *align(8) const Buffer(.ambiguous), readable_status: ReadOnly) Layout {
        return .{
            .tag = .init(false, readable_status),
            .buffer = .{ .strbuf = @constCast(buffer) },
            .start = 0,
            .len = buffer.len
        };
    }

    pub fn ref(self: *align(8) @This()) gzzg.String {
        return .{ .s = @ptrCast(self) };
    }

    pub fn refConst(self: *const align(8) @This()) gzzg.String {
        // is this the right way to make safer?
        std.debug.assert(self.tag.readable_status == .just_readable); 
        return .{ .s = @constCast(@ptrCast(self)) };
    }

    pub fn from(self: gzzg.String) *align(8) Layout {
        return @alignCast(@ptrCast(self.s));
    }

    // string tests required
    // expect cons tag
    // expect cons.0 to be a string tag
    // expect cons.1 to be a cons tag
    // expect cons.1.0 to be stringbuf tag
    // expect const.1.0.1 to be a number,
    // expect cons.1.0.2 to be the buffer
    
    pub fn is(s: anytype) bool {
        iw.assertTagged(@TypeOf(s));
        if (!(!iw.isImmediate(s) and iw.getTCFor(iw.TC3, s) == .cons))
            return false;
        
        const c0 = iw.untagSCM(s)[0];
        const c1 = iw.untagSCM(s)[1];
        
        if (!(iw.isImmediate(c0) and
            iw.getTCFor(iw.TC3, c0) == .tc7 and
            iw.getTCFor(iw.TC7, c0) == .string and
            !iw.isImmediate(c1) and
            iw.getTCFor(iw.TC3, c1) == .cons))
            return false;

        const v0 = iw.untagSCM(c1)[0];

        return iw.isImmediate(v0) and
            iw.getTCFor(iw.TC3, v0) == .tc7_2 and
            iw.getTCFor(iw.TC7, v0) == .stringbuf;
    }

    pub fn getSlice(self: *align(8) @This()) BufferSlice {
        //todo deal with shared
        return switch (self.buffer.strbuf.getSlice()) {
            .narrow => |ns| .{ .narrow = ns[self.start..][0..self.len]},
            .wide => |ws| .{ .wide = ws[self.start..][0..self.len] },
        };
    }

    const Tag = packed struct(iw.SCMBits) {
        tc7: iw.TC7,
        _padding1: Padding(1) = .nil,
        shared: bool,
        readable_status: ReadOnly,
        _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7 + 1 + 1 + 1)) = .nil,
        
        pub fn init(is_shared: bool, readable_status: ReadOnly) @This() {
            return .{
                .tc7 = .string,
                .shared = is_shared,
                .readable_status = readable_status,
            };
        }
    };
};

pub const ReadOnly = enum (u1) {
    read_and_write = 0,
    just_readable = 1,
};

pub const Mutability = enum (u1) {
    immutable = 0,
    mutable = 1,
};

pub const BufferOptions = union(enum) {
    ambiguous,
    fixed: struct {
        backing: CharacterWidth,
        len: comptime_int
    }, // consider runtime stringbuf option?
};


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
        
        fn initFixed(str_utf8: []const u8, mutable: Mutability) !@This() {
            const fixed = options.fixed;
            
            var sb = @This(){
                .tag = .init(fixed.backing, mutable),
            };
            
            const written = try fixed.backing.encodeStatic(str_utf8, &sb.buffer);
            sb.len = written;
            sb.buffer[sb.len] = 0;

            return sb;
        }

        fn initRuntime(allocator: std.mem.Allocator, str_utf8: []const u8, mutable: Mutability) !*align(8) Buffer(.ambiguous) {
            const cw = try CharacterWidth.fits(str_utf8);
            
            const len:usize, const bytes_extra:usize = init: switch (cw) {
                inline else => |w| {
                    const str_len = try w.lenIn(str_utf8);
                    
                    break :init .{ str_len, str_len * @sizeOf(w.backingType()) };
                }
            };

            // todo: consider using allocator.allocSentinel
            const full_size = @sizeOf(Buffer(.ambiguous)) + bytes_extra + 1;
            const al = try allocator.alignedAlloc(u8, 8, full_size);
            const b: *align(8) Buffer(.ambiguous) = @ptrCast(al);

            b.tag = .init(cw, mutable);

            switch (cw) {
                inline else => |w| {
                    const ptr = b.getBufferPtr(w.backingType());
                    _ = try w.encodeStatic(str_utf8, ptr[0..len]);
                    
                    ptr[len] = 0;
                }
            }

            b.len = len;

            return b;
        }

        pub fn free(self: *Self, allocator: std.mem.Allocator) void {
            const extra_bytes = switch (self.tag.width) { inline else => |w| self.len * @sizeOf(w.backingType()) };
            const full_size = @sizeOf(Buffer(.ambiguous)) + extra_bytes + 1;
            
            allocator.free(@as([*]align(8) u8, @ptrCast(self))[0..full_size]);
        }

        pub const getSliceExact = switch (options) {
            .ambiguous => @compileError("Can't grab an exact slice of an ambiguous string buffer"),
            .fixed => |f| struct {
                fn getSliceExact(self: *Self) [:0]f.backing.backingType() {
                    return &self.buffer;
                }
            }.getSliceExact,
        };

        fn getBufferPtr(self: *Self, TW: type) [*:0]TW {
            return @ptrCast(&self.buffer);
        }

        pub fn getSlice(self: *align(8) Self) BufferSliceSentinel {
            switch (options) {
                .ambiguous => {
                    return switch (self.tag.width) {
                        .wide =>   .{ .wide   = @ptrCast(self.getBufferPtr(CharacterWidth.wide.backingType())[0..self.len])},
                        .narrow => .{ .narrow = @ptrCast(self.getBufferPtr(CharacterWidth.narrow.backingType())[0..self.len])
                        },
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

        fn OfMatchingPointer(p: type, Child: type) type {
            const info = @typeInfo(p).pointer;

            if (info.alignment < 8)
                @compileError("Incorrect alignment");

            return if (info.is_const)
                *align(info.alignment) const Child
            else
                *align(info.alignment) Child;
        }

        pub inline fn ambiguation(self: anytype) OfMatchingPointer(@TypeOf(self), Buffer(.ambiguous)) {
            return @ptrCast(self);
        }

        pub const Tag = packed struct(iw.SCMBits) {
            tc7: iw.TC7,
            _padding1: Padding(3) = .nil,
            width: CharacterWidth,
            mutable: Mutability,
            _padding_end: Padding(@bitSizeOf(iw.SCMBits) - (7 + 3 + 1 + 1)) = .nil,
            
            pub fn init(char_width: CharacterWidth, mutate: Mutability) @This() {
                return .{
                    .tc7 = .stringbuf,
                    .width = char_width,
                    .mutable = mutate
                };
            }
        };
    };
}

pub fn BufferFrom(comptime str_utf8:[] const u8) type {
    const backing = encoding.CharacterWidth.fits(str_utf8)
        catch |err| @compileError(@errorName(err));
    const len_encoded = backing.lenInComptime(str_utf8);

    return Buffer(.{ .fixed = .{ .backing = backing, .len = len_encoded }});
}

pub inline fn staticBuffer(comptime str_utf8:[]const u8) BufferFrom(str_utf8) {
    @setEvalBranchQuota(10_000); // how big?
    comptime { // is this the best way to hint that this is a comptime only function?
        return BufferFrom(str_utf8).init(str_utf8, .immutable) catch |err| @compileError(@errorName(err));
    }
}

pub inline fn runtimeBuffer(allocator: std.mem.Allocator, str_utf8:[]const u8, mutable: Mutability) !*align(8) Buffer(.ambiguous) {
    return .initRuntime(allocator, str_utf8, mutable);
}

//
//
//

fn expectSamePtr(expected: anytype, actual: anytype) !void {
    try std.testing.expectEqual(@intFromPtr(expected), @intFromPtr(actual));
}


test "guile static string .narrow" {
    const expectEqual = std.testing.expectEqual;
    gzzg.initThreadForGuile();

    const str = "Smoke me a kipper, I'll be back for breakfast";
    const strbuf align(8) = staticBuffer(str);
    var layout align(8) = Layout.init(strbuf.ambiguation(), .just_readable);

    const gstr = layout.ref();

    try expectEqual(str.len, gstr.lenZ());

    var itr = gstr.iterator();
    var idx: usize = 0;
    while (itr.next()) |c| : (idx += 1) {
        try expectEqual(str[idx], (try c.toZ()).getOne());
    }
}

test "guile static string .wide" {
    const expectEqual        = std.testing.expectEqual;
    const expectEqualStrings = std.testing.expectEqualStrings;
    const Char               = gzzg.Character;
    gzzg.initThreadForGuile();

    const u = std.unicode;

    // Qrrc Oyhr–Xnfcnebi, 1996, eq 1
    // ♔♕♖♗♘♙
    // ♚♛♜♝♞♟
    const str =
        \\    abcdefgh
        \\   ╔════════╗
        \\ 8 ║        ║
        \\ 7 ║       ♜║
        \\ 6 ║     ♕ ♔║
        \\ 5 ║   ♛  ♞ ║
        \\ 4 ║   ♙    ║
        \\ 3 ║♟♟   ♙♟♟║
        \\ 2 ║     ♘ ♚║
        \\ 1 ║    ♖   ║
        \\   ╚════════╝ 
    ;
    const strbuf align(8) = staticBuffer(str);
    var layout align(8) = Layout.init(strbuf.ambiguation(), .just_readable);

    const gstr = layout.ref();

    try expectEqual(try u.utf8CountCodepoints(str), gstr.lenZ());

    var view = try u.Utf8View.init(str);
    var itr = view.iterator();
    var gitr = gstr.iterator();

    var gchar:?Char = gitr.next();
    var char:?[] const u8 = itr.nextCodepointSlice();
    while (true) : ({
        gchar = gitr.next();
        char  = itr.nextCodepointSlice();
    }) {
        if (gchar == null and char == null)
            break;
        
        if (gchar == null or char == null) 
            return error.DoNotMatch;

        try expectEqualStrings(char.?, (try gchar.?.toZ()).getConst());   
    }
}

// todo: consider test naming
test "Static String: substring" {
    //const expect    = std.testing.expect;
    const expectEql = std.testing.expectEqual;
    const expectStr = std.testing.expectEqualStrings;
    const Int = gzzg.Integer;
    gzzg.initThreadForGuile();

    const str = "Nothing useless can be truly beautiful.";
    const buf align(8) = staticBuffer(str);
    var lay align(8) = Layout.init(buf.ambiguation(), .just_readable);
    const gstr = lay.ref();

    try expectEql(gstr.lenZ(), str.len);

    { // snip "truly"
        const gss = gstr.substring(Int.from(23), Int.from(28));

        // Should still share the same Buffer
        try expectSamePtr(&buf, Layout.from(gss).buffer.strbuf);
        
        var fba_buffer:[6] u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&fba_buffer);
        
        const out_str = try gss.toUTF8(fba.allocator());

        try expectStr(str[23..28], out_str);
    }
}

test "Runtime String" {
    const expectStr = std.testing.expectEqualStrings;
    const Int = gzzg.Integer;
    var dalloc = std.heap.DebugAllocator(.{}){};
    const alloc = dalloc.allocator();
    defer _ = dalloc.deinit();
    gzzg.initThreadForGuile();

    const str = "Remarkable Colour";
    const buf = try runtimeBuffer(alloc, str, .immutable);
    defer buf.free(alloc);

    try expectStr(str, buf.getSlice().narrow);


    const lay = try alloc.alignedAlloc(Layout, 8, 1);
    defer alloc.free(lay);

    lay[0] = .init(buf, .just_readable);

    { // snip "Colour"
        const gss = lay[0].ref().substring(Int.from(11), null);

        // Should still share the same Buffer
        try expectSamePtr(buf, Layout.from(gss).buffer.strbuf);
        
        const out_str = try gss.toUTF8(alloc);
        defer alloc.free(out_str);

        try expectStr(str[11..], out_str);
    }
}

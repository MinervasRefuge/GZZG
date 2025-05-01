// cellular_automaton.zig : Example of Guile Foreign Types using GZZG
// with the example of Cellular Automaton.
// Copyright (C) 2025  Abigale Raeck
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// zig fmt: off
const std   = @import("std");

const Tuple = std.meta.Tuple;
const cPrint = std.fmt.comptimePrint;
// zig fmt: on

//
// "Basic" utilities
//

fn joinInfixLen(comptime join: []const u8, list_strs: []const []const u8) comptime_int {
    if (list_strs.len == 0) return 0;
    var len = join.len * (list_strs.len - 1);
    for (list_strs) |str| len += str.len;

    return len;
}

fn joinInfix(comptime join_str: []const u8, list_strs: []const []const u8) *const [joinInfixLen(join_str, list_strs):0]u8 {
    return switch (list_strs.len) {
        0 => "",
        1 => list_strs[0] ++ "",
        else => ret: {
            var buffer = list_strs[0];
            for (list_strs[1..]) |str| buffer = buffer ++ join_str ++ str;
            break :ret buffer;
        },
    };
}

const console = struct {
    const Colour = struct {
        red: u8,
        green: u8,
        blue: u8,
    };

    const ColourOptionsTag = enum(u8) {
        predefined = 5,
        real = 2,
    };

    const ColourOptions = union(ColourOptionsTag) {
        predefined: u8,
        real: Colour,
    };

    const CSITag = enum(u8) {
        // A-H, J, K, S, T, f, m, 5i, 4i, 6n

        cursor_position = 'H',
        erase_in_display = 'J',
        selected_graphic_rendition = 'm',

        cursor_show = 'h',
        cursor_hide = 'l',
    };

    /// control sequence introducer
    pub const CSI = union(CSITag) {
        const start = "\x1B[";

        /// CUP
        cursor_position: ?XY,
        /// ED
        erase_in_display: enum(u8) {
            to_end = 0,
            to_beginning = 1,
            entire = 2,
            entire_and_clear_buffer = 3,
        },
        /// SGR
        selected_graphic_rendition: []const SGR,

        cursor_show: void,
        cursor_hide: void,

        pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
            const dcode = @intFromEnum(self);
            switch (self) {
                .cursor_position => |p| {
                    if (p) |has| {
                        try writer.print("{s}{d};{d}{c}", .{ start, has.x, has.y, dcode });
                    } else {
                        try writer.print("{s}{c}", .{ start, dcode });
                    }
                },
                .erase_in_display => |erase| {
                    try writer.print("{s}{d}{c}", .{ start, @intFromEnum(erase), dcode });
                },
                .selected_graphic_rendition => |sgr| {
                    try writer.print("{s}{s}{c}", .{ start, SGR.compose(sgr), dcode });
                },
                .cursor_show, .cursor_hide => {
                    try writer.print("{s}?25{c}", .{ start, dcode });
                },
            }
        }

        fn toComptimeString(comptime self: @This()) []const u8 {
            return cPrint("{}", .{self});
        }
    };

    const SGRTag = enum(u8) {
        // zig fmt: off
        normal = 0,
        bold   = 1,
        dim    = 2,
        italic = 3,
        
        foreground_black   = 30,
        foreground_red     = 31,
        foreground_green   = 32,
        foreground_yellow  = 33,
        foreground_blue    = 34,
        foreground_magenta = 35,
        foreground_cyan    = 36,
        foreground_white   = 37,
        foreground         = 38,
        
        background_black   = 40,
        background_red     = 41,
        background_green   = 42,
        background_yellow  = 43,
        background_blue    = 44,
        background_magenta = 45,
        background_cyan    = 46,
        background_white   = 47,
        background         = 48,
        // zig fmt: on
    };

    /// Select Graphic Rendition
    pub const SGR = union(SGRTag) {
        // zig fmt: off
        normal: void,
        bold  : void,
        dim   : void,
        italic: void,
        
        foreground_black  : void, 
        foreground_red    : void, 
        foreground_green  : void, 
        foreground_yellow : void, 
        foreground_blue   : void, 
        foreground_magenta: void, 
        foreground_cyan   : void, 
        foreground_white  : void, 
        foreground        : ColourOptions, 
        
        background_black  : void,
        background_red    : void,
        background_green  : void,
        background_yellow : void,
        background_blue   : void,
        background_magenta: void,
        background_cyan   : void,
        background_white  : void,
        background        : ColourOptions,
        // zig fmt: on

        pub fn compose(comptime codes: []const SGR) []const u8 {
            var strs: [codes.len][]const u8 = undefined;

            for (codes, 0..) |code, idx| {
                const dcode = @intFromEnum(code);
                switch (code) {
                    .foreground, .background => |ground| {
                        const dground = @intFromEnum(ground);

                        strs[idx] = switch (ground) {
                            .predefined => |p| cPrint("{d};{d};{d}", .{ dcode, dground, p }),
                            .real => |r| cPrint("{d};{d};{d};{d};{d}", .{ dcode, dground, r.red, r.green, r.blue }),
                        };
                    },
                    else => strs[idx] = cPrint("{d}", .{dcode}),
                }
            }

            return joinInfix(";", &strs);
        }
    };
};

const XY = struct {
    x: usize,
    y: usize,

    pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
        try writer.print("({d},{d})", .{ self.x, self.y });
    }
};

const SetWorldError = error{ InvalidMapCharacter, OutsideMapBounds };

fn Map(comptime msize: XY, comptime Child: type) type {
    const Arr = [msize.x * msize.y]Child;

    return struct {
        size: XY = msize,

        b1: Arr = std.mem.zeroes(Arr),
        b2: Arr = std.mem.zeroes(Arr),

        fn flipBuffer(self: *@This()) FlipBuffer(Child) {
            return .{
                .b1 = &self.b1,
                .b2 = &self.b2,
            };
        }

        fn setWorld(self: *@This(), state: []const []const u8) SetWorldError!void {
            for (state, 0..) |x_row, y| {
                if (y >= self.size.y) return error.OutsideMapBounds;
                for (x_row, 0..) |point, x| {
                    if (x >= self.size.x) return error.OutsideMapBounds;
                    const idx = y * self.size.x + x;
                    const cell =
                        if (Child.fromChar(point)) |c| c else return error.InvalidMapCharacter;

                    self.b1[idx] = cell;
                    self.b2[idx] = cell;
                }
            }
        }
    };
}

fn assertMap(comptime M: type) void {
    const T = @typeInfo(M).pointer.child;
    if (!(@hasField(T, "size") and
        @hasDecl(T, "flipBuffer") and
        @hasDecl(T, "setWorld")))
        @compileError("Not a map type");
}

fn FlipBuffer(comptime Child: type) type {
    return struct {
        b1: []Child,
        b2: []Child,
        flip: bool = true,

        pub fn toggle(self: *@This()) void {
            self.flip = !self.flip;
        }

        pub fn buffer(self: *@This()) Tuple(&.{ []Child, []Child }) {
            return if (self.flip)
                .{ self.b1, self.b2 }
            else
                .{ self.b2, self.b1 };
        }

        pub fn bufferConst(self: *const @This()) Tuple(&.{ []const Child, []const Child }) {
            return if (self.flip)
                .{ self.b1, self.b2 }
            else
                .{ self.b2, self.b1 };
        }
    };
}

//        /\          /\          /\          /\
//     /\//\\/\    /\//\\/\    /\//\\/\    /\//\\/\
//  /\//\\\///\\/\//\\\///\\/\//\\\///\\/\//\\\///\\/\
// //\\\//\/\\///\\\//\/\\///\\\//\/\\///\\\//\/\\///\\
// \\//\/                                        \/\\//
//  \/       ░█▀▀░█▀▀░█░░░█░░░█░█░█░░░█▀█░█▀▄       \/
//  /\       ░█░░░█▀▀░█░░░█░░░█░█░█░░░█▀█░█▀▄       /\
// //\\      ░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀░▀      //\\
// \\//    ░█▀█░█░█░▀█▀░█▀█░█▄█░█▀█░▀█▀░█▀█░█▀█    \\//
//  \/     ░█▀█░█░█░░█░░█░█░█░█░█▀█░░█░░█░█░█░█     \/
//  /\     ░▀░▀░▀▀▀░░▀░░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░▀░▀     /\
// //\\/\                                        /\//\\
// \\///\\/\//\\\///\\/\//\\\///\\/\//\\\///\\/\//\\\//
//  \/\\///\\\//\/\\///\\\//\/\\///\\\//\/\\///\\\//\/
//     \/\\//\/    \/\\//\/    \/\\//\/    \/\\//\/
//        \/          \/          \/          \/

pub fn AutomatonIterator(comptime window: XY, comptime ICell: type, comptime rule: fn (XY, [][]const ICell) ICell) type {
    _ = @typeInfo(ICell).@"enum";

    const offset: XY = .{
        .x = @divExact(window.x - 1, 2),
        .y = @divExact(window.y - 1, 2),
    };

    return struct {
        pub const Cell = ICell;

        size: XY,
        fbuffer: FlipBuffer(Cell),

        fn next(self: *@This()) void {
            var view: [window.y][]const ICell = undefined;
            const read, const write = self.fbuffer.buffer();
            self.fbuffer.toggle();

            const size = self.size;

            for (write, 0..) |*w, idx| {
                const x = idx % size.x;
                const y = idx / size.x;

                const min: XY = .{
                    .x = x -| offset.x,
                    .y = y -| offset.y,
                };

                const max: XY = .{
                    .x = @min(x + offset.x + 1, size.x),
                    .y = @min(y + offset.y + 1, size.y),
                };

                const y_range = max.y - min.y;
                for (0..y_range) |wy| {
                    const row = (min.y + wy) * size.x;
                    view[wy] = read[row + min.x .. row + max.x];
                }

                const centre: XY = .{
                    .x = if (x < offset.x) x else offset.x,
                    .y = if (y < offset.y) y else offset.y,
                };

                w.* = rule(centre, view[0..y_range]);
            }
        }

        pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
            const b = self.fbuffer.bufferConst()[0];

            for (b, 0..) |p, idx| {
                if (idx % self.size.x == 0 and idx != 0) try writer.writeByte('\n');
                try writer.print("{}", .{p});
            }
        }
    };
}

const WireWorld = struct {
    const window: XY = .{ .x = 3, .y = 3 };
    const Cell = enum {
        empty,
        electron_head,
        electron_tail,
        conductor,

        pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
            const r = comptime (console.CSI{ .selected_graphic_rendition = &.{.background_red} }).toComptimeString();
            const b = comptime (console.CSI{ .selected_graphic_rendition = &.{.background_blue} }).toComptimeString();
            const y = comptime (console.CSI{ .selected_graphic_rendition = &.{.background_yellow} }).toComptimeString();
            const off = comptime (console.CSI{ .selected_graphic_rendition = &.{.normal} }).toComptimeString();

            try writer.writeAll(switch (self) {
                .empty => " ",
                .electron_head => r ++ "*" ++ off,
                .electron_tail => b ++ "⋅" ++ off,
                .conductor => y ++ " " ++ off,
            });
        }

        pub fn fromChar(c: u8) ?@This() {
            return switch (c) {
                '*' => .conductor,
                'E' => .electron_head,
                't' => .electron_tail,
                ' ' => .empty,
                else => null,
            };
        }
    };

    const Iterator = AutomatonIterator(window, Cell, rule);

    fn rule(centre: XY, view: [][]const Cell) Cell {
        return switch (view[centre.y][centre.x]) {
            .empty => .empty,
            .electron_head => .electron_tail,
            .electron_tail => .conductor,
            .conductor => ret: {
                var neighbours: u8 = 0;
                for (view, 0..) |x_row, wy| {
                    for (x_row, 0..) |point, wx| {
                        if (!(wy == centre.y and wx == centre.x))
                            neighbours += @intFromBool(point == .electron_head);
                    }
                }

                break :ret switch (neighbours) {
                    1, 2 => .electron_head,
                    else => .conductor,
                };
            },
        };
    }

    fn iterator(map: anytype) Iterator {
        assertMap(@TypeOf(map));
        return .{
            .size = map.size,
            .fbuffer = map.flipBuffer(),
        };
    }
};

const ConwaysGameOfLife = struct {
    const window: XY = .{ .x = 3, .y = 3 };
    const Cell = enum {
        dead,
        alive,

        pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
            try writer.writeAll(switch (self) {
                .dead => " ",
                .alive => "█",
            });
        }

        pub fn fromChar(c: u8) ?@This() {
            return switch (c) {
                '*' => .alive,
                ' ' => .dead,
                else => null,
            };
        }
    };

    const Iterator = AutomatonIterator(window, Cell, rule);

    fn rule(centre: XY, view: [][]const Cell) Cell {
        var neighbours: u8 = 0;
        for (view, 0..) |x_row, wy| {
            for (x_row, 0..) |point, wx| {
                if (!(wy == centre.y and wx == centre.x))
                    neighbours += @intFromBool(point == .alive);
            }
        }

        return switch (view[centre.y][centre.x]) {
            .dead => if (neighbours == 3) .alive else .dead,
            .alive => switch (neighbours) {
                2, 3 => .alive,
                else => .dead,
            },
        };
    }

    fn iterator(map: anytype) Iterator {
        assertMap(@TypeOf(map));
        return .{
            .size = map.size,
            .fbuffer = map.flipBuffer(),
        };
    }
};

pub fn main() !void {
    const clear = comptime (console.CSI{ .erase_in_display = .entire }).toComptimeString();
    const seek_home = comptime (console.CSI{ .cursor_position = null }).toComptimeString();
    const hide = comptime (console.CSI{ .cursor_hide = {} }).toComptimeString();
    const show = comptime (console.CSI{ .cursor_show = {} }).toComptimeString();
    const pause_for = 80_000_000;

    defer std.debug.print(show, .{});

    std.debug.print(hide ++ clear, .{});
    {
        const size: XY = .{ .x = 22, .y = 11 };
        var map: Map(size, WireWorld.Cell) = .{};

        // XOR with 2 clocks
        try map.setWorld(&.{
            "                     ",
            "  ***tE              ",
            " *     ****          ",
            "  *****    *         ",
            "          ****       ",
            "          *  ******* ",
            "          ****       ",
            "  ***tE    *         ",
            " *     ****          ",
            "  Et***              ",
            "                     ",
        });

        var ww = WireWorld.iterator(&map);
        for (0..75) |_| {
            ww.next();
            std.debug.print(seek_home ++ "{}", .{ww});
            std.Thread.sleep(pause_for);
        }
    }

    std.debug.print(clear, .{});
    {
        const size: XY = .{ .x = 42 + 25, .y = 30 };
        var map: Map(size, ConwaysGameOfLife.Cell) = .{};

        // Gosper glider gun
        try map.setWorld(&.{
            "                                          ",
            "                           *              ",
            "                         * *              ",
            "               **      **            **   ",
            "              *   *    **            **   ",
            "   **        *     *   **                 ",
            "   **        *   * **    * *              ",
            "             *     *       *              ",
            "              *   *                       ",
            "               **                         ",
            "                                          ",
        });

        var cgol = ConwaysGameOfLife.iterator(&map);
        for (0..125) |_| {
            cgol.next();
            std.debug.print(seek_home ++ "{}", .{cgol});
            std.Thread.sleep(pause_for);
        }
    }

    std.debug.print(clear ++ seek_home, .{});
}

//        /\          /\          /\          /\
//     /\//\\/\    /\//\\/\    /\//\\/\    /\//\\/\
//  /\//\\\///\\/\//\\\///\\/\//\\\///\\/\//\\\///\\/\
// //\\\//\/\\///\\\//\/\\///\\\//\/\\///\\\//\/\\///\\
// \\//\/                                        \/\\//
//  \/               ░█░█░▀█▀░▀█▀░█░█               \/
//  /\               ░█▄█░░█░░░█░░█▀█               /\
// //\\              ░▀░▀░▀▀▀░░▀░░▀░▀              //\\
// \\//  ░█▀▀░▀▀█░▀▀█░█▀▀░░░█░█▀▀░█░█░▀█▀░█░░░█▀▀  \\//
//  \/   ░█░█░▄▀░░▄▀░░█░█░▄▀░░█░█░█░█░░█░░█░░░█▀▀   \/
//  /\   ░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀   /\
// //\\/\                                        /\//\\
// \\///\\/\//\\\///\\/\//\\\///\\/\//\\\///\\/\//\\\//
//  \/\\///\\\//\/\\///\\\//\/\\///\\\//\/\\///\\\//\/
//     \/\\//\/    \/\\//\/    \/\\//\/    \/\\//\/
//        \/          \/          \/          \/

// zig fmt: off
const gzzg = @import("gzzg");
const AList      = gzzg.buoy.basic.AList;
const Any        = gzzg.Any;
const ByteVector = gzzg.ByteVector;
const Integer    = gzzg.Integer;
const ListOf     = gzzg.ListOf;
const Procedure  = gzzg.Procedure;
const String     = gzzg.String;
const Symbol     = gzzg.Symbol;
const buoy       = gzzg.buoy.basic.from;
const guile      = gzzg.guile;
// zig fmt: on

const module_name = "cellular-automaton";

export fn initPlugin() void {
    _ = gzzg.Module.define(module_name, initModule);
}

fn initModule() void {
    CAMap.register();
    CAIterator.register();
}

const CAMap = struct {
    const ix_name = "map";
    const guile_name = module_name ++ "-" ++ ix_name;
    var gc = gzzg.GuileGCAllocator{ .what = guile_name };
    const Foreign = gzzg.ForeignObjectOf(@This(), guile_name, .{ .size, .b1, .b2 }, null);

    size: *XY,
    b1: ByteVector,
    b2: ByteVector,

    fn register() void {
        Foreign.registerType();
        _ = Procedure.define("make-" ++ ix_name, make, null, true);
        _ = Procedure.define(ix_name ++ "-size", getSize, null, true);
    }

    fn make(x: Integer, y: Integer) !Foreign {
        if (x.lowerNumber().isNegative().toZ() or
            y.lowerNumber().isNegative().toZ() or
            x.lowerNumber().isZero().toZ() or
            y.lowerNumber().isZero().toZ()) return error.InvalidSize;

        const size = try gc.allocator().create(XY);
        const len = x.product(y);

        size.* = .{
            .x = x.toZ(usize),
            .y = y.toZ(usize),
        };

        return .make(.{
            .size = size,
            .b1 = ByteVector.make(len, Integer.from(0)),
            .b2 = ByteVector.make(len, Integer.from(0)),
        });
    }

    fn getSize(self: Foreign) AList {
        return buoy(self.getSlot(.size).*, .{});
    }

    fn flipBuffer(self: CAMap, comptime Child: type) FlipBuffer(Child) {
        if (@sizeOf(Child) > @sizeOf(u8)) @compileError("BAD WOLF");

        return .{
            .b1 = @ptrCast(self.b1.contents(u8)),
            .b2 = @ptrCast(self.b2.contents(u8)),
        };
    }
};

const CAIterator = struct {
    const ix_name = "iterator";
    const guile_name = module_name ++ "-" ++ ix_name;
    var gc = gzzg.GuileGCAllocator{ .what = guile_name };
    const Foreign = gzzg.ForeignObjectOf(@This(), guile_name, .{ .map, .itr }, null);

    const Automatons = union(enum) {
        const display_names = &.{ "conways-game-of-life", "wire-world" };
        const cache = gzzg.StaticCache(Symbol, Symbol.fromUTF8, display_names);

        cgol: ConwaysGameOfLife.Iterator,
        ww: WireWorld.Iterator,
    };

    map: CAMap.Foreign,
    itr: *Automatons,

    fn register() void {
        Foreign.registerType();
        _ = Procedure.define("make-" ++ ix_name, make, null, true);
        _ = Procedure.define(ix_name ++ "-next", next, null, true);
        _ = Procedure.define(ix_name ++ "-print", print, null, true);
        _ = Procedure.define(ix_name ++ "-world!", setWorld, null, true);
    }

    fn make(catype: Symbol, map: CAMap.Foreign) !Foreign {
        const itr = try gc.allocator().create(Automatons);
        const hash = catype.hash();
        var has = false;

        inline for (std.meta.fields(Automatons), Automatons.display_names) |field, name| {
            if (Automatons.cache.get(name).hash().equal(hash).toZ()) {
                itr.* = @unionInit(Automatons, field.name, .{
                    .size = map.getSlot(.size).*,
                    .fbuffer = map.assemble().flipBuffer(field.type.Cell),
                });

                has = true;
                break;
            }
        }

        if (has) {
            return .make(.{ .itr = itr, .map = map });
        } else {
            return error.UnknownAutomaton;
        }
    }

    // todo: This could be improved
    fn next(self: Foreign) void {
        const ptr = self.getSlot(.itr);
        switch (ptr.*) {
            //inline else => |*u| u.next(),
            .cgol => ptr.cgol.next(),
            .ww => ptr.ww.next(),
        }
    }

    // todo: This could be improved
    fn print(self: Foreign) void {
        const ptr = self.getSlot(.itr);
        switch (ptr.*) {
            //inline else => |*u| u.next(),
            .cgol => std.debug.print("{}\n", .{ptr.cgol}),
            .ww => std.debug.print("{}\n", .{ptr.ww}),
        }
    }

    // todo: This could be improved
    fn setWorld(self: Foreign, list: ListOf(String)) !void {
        const map = self.getSlot(.map).assemble();
        const atmn = self.getSlot(.itr);

        const b1 = map.b1.contents(u8);
        const b2 = map.b2.contents(u8);

        var litr = list.iterator();
        var y: usize = 0;
        while (litr.next()) |row| : (y += 1) {
            if (y >= map.size.y) return error.OutsideMapBounds;

            var chitr = row.iterator();
            var x: usize = 0;
            while (chitr.next()) |gchar| : (x += 1) {
                if (x >= map.size.x) return error.OutsideMapBounds;

                const idx = y * map.size.x + x;
                const char = (try gchar.toZ()).getOne();
                const cell = switch (atmn.*) {
                    .cgol => if (ConwaysGameOfLife.Cell.fromChar(char)) |c|
                        @intFromEnum(c)
                    else
                        return error.InvalidMapCharacter,
                    .ww => if (WireWorld.Cell.fromChar(char)) |c|
                        @intFromEnum(c)
                    else
                        return error.InvalidMapCharacter,
                };

                b1[idx] = cell;
                b2[idx] = cell;
            }
        }
    }
};

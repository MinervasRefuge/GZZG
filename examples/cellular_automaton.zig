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
const gzzg  = @import("gzzg");
const guile = gzzg.guile;

const Tuple = std.meta.Tuple;

// zig fmt: on

const XY = struct {
    x: usize,
    y: usize,

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("({d},{d})", .{ self.x, self.y });
    }
};

// todo: Change
fn Map(comptime size: XY, comptime Backing: type) type {
    return [size.x * size.y]Backing;
}

fn FlipBuffer(comptime Backing: type) type {
    return struct {
        b1: []Backing,
        b2: []Backing,
        flip: bool = false,

        pub fn toggle(self: *@This()) void {
            self.flip = !self.flip;
        }

        pub fn buffer(self: *@This()) Tuple(&.{ []Backing, []Backing }) {
            return if (self.flip)
                .{ self.b1, self.b2 }
            else
                .{ self.b2, self.b1 };
        }

        pub fn bufferConst(self: *const @This()) Tuple(&.{ []const Backing, []const Backing }) {
            return if (self.flip)
                .{ self.b1, self.b2 }
            else
                .{ self.b2, self.b1 };
        }
    };
}

pub fn AutomatonIterator(comptime window: XY, comptime Cell: type, comptime rule: fn (XY, [][]const Cell) Cell) type {
    _ = @typeInfo(Cell).@"enum";

    // assert window dimentions is odd

    const offset: XY = .{
        .x = @divExact(window.x - 1, 2),
        .y = @divExact(window.y - 1, 2),
    };

    return struct {
        size: XY,
        map: FlipBuffer(Cell),

        fn next(self: *@This()) void {
            var view: [window.y][]const Cell = undefined;
            const read, const write = self.map.buffer();
            self.map.toggle();

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

        pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            const b = self.map.bufferConst()[0];

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

        pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            const bk = .{
                .red = "\x1B[41m",
                .blue = "\x1B[44m",
                .yellow = "\x1B[43m",
            };

            const off = "\x1B[0m";

            try writer.writeAll(switch (self) {
                .empty => " ",
                .electron_head => bk.red ++ "*" ++ off,
                .electron_tail => bk.blue ++ "⋅" ++ off,
                .conductor => bk.yellow ++ " " ++ off,
            });
        }
    };

    fn rule(centre: XY, view: [][]const Cell) Cell {
        return switch (view[centre.y][centre.x]) {
            // zig fmt: off
            .empty         => .empty,
            .electron_head => .electron_tail,
            .electron_tail => .conductor,
            // zig fmt: on
            .conductor => ret: {
                var count: u8 = 0;
                for (view, 0..) |x_row, wy| {
                    for (x_row, 0..) |point, wx| {
                        if (!(wy == centre.y and wx == centre.x)) {
                            count += @intFromBool(point == .electron_head);
                        }
                    }
                }

                break :ret switch (count) {
                    1, 2 => .electron_head,
                    else => .conductor,
                };
            },
        };
    }

    fn iterator(size: XY, b1: []Cell, b2: []Cell) AutomatonIterator(window, Cell, rule) {
        return .{
            .size = size,
            .map = .{
                .b1 = b1,
                .b2 = b2,
            },
        };
    }

    fn setWorld(size: XY, state: []const []const u8, map: []Cell) void {
        for (state, 0..) |x_row, y| {
            for (x_row, 0..) |point, x| {
                map[y * size.x + x] = switch (point) {
                    '*' => .conductor,
                    'E' => .electron_head,
                    't' => .electron_tail,
                    ' ' => .empty,
                    else => @panic("Not Valid"),
                };
            }
        }
    }
};

const ConwaysGameOfLife = struct {
    const window: XY = .{ .x = 3, .y = 3 };

    const Cell = enum {
        dead,
        alive,

        pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.writeAll(switch (self) {
                .dead => " ",
                .alive => "█",
            });
        }
    };

    fn rule(centre: XY, view: [][]const Cell) Cell {
        var count: u8 = 0;
        for (view, 0..) |x_row, wy| {
            for (x_row, 0..) |point, wx| {
                if (!(wy == centre.y and wx == centre.x)) {
                    count += @intFromBool(point == .alive);
                }
            }
        }

        return switch (view[centre.y][centre.x]) {
            // zig fmt: off
            .dead  => if (count == 3) .alive else .dead,
            .alive => switch (count) {
                2, 3 => .alive,
                else => .dead,
            },
            // zig fmt: on
        };
    }

    fn iterator(size: XY, b1: []Cell, b2: []Cell) AutomatonIterator(window, Cell, rule) {
        return .{
            .size = size,
            .map = .{
                .b1 = b1,
                .b2 = b2,
            },
        };
    }

    fn setWorld(size: XY, state: []const []const u8, map: []Cell) void {
        for (state, 0..) |x_row, y| {
            for (x_row, 0..) |point, x| {
                map[y * size.x + x] = switch (point) {
                    '*' => .alive,
                    ' ' => .dead,
                    else => @panic("Not Valid"),
                };
            }
        }
    }
};

pub fn main() !void {
    const clear_and_home = "\x1B[H";
    const pause_for = 80_000_000;

    {
        const size: XY = .{ .x = 22, .y = 11 };
        var b1 = std.mem.zeroes(Map(size, WireWorld.Cell));
        var b2 = std.mem.zeroes(Map(size, WireWorld.Cell));

        // XOR with 2 clocks
        WireWorld.setWorld(size, &.{
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
        }, &b2);

        var ww = WireWorld.iterator(size, &b1, &b2);
        for (0..75) |_| {
            ww.next();
            std.debug.print(clear_and_home ++ "{}", .{ww});
            std.Thread.sleep(pause_for);
        }
    }

    {
        const size: XY = .{ .x = 42 + 25, .y = 30 };
        var b1 = std.mem.zeroes(Map(size, ConwaysGameOfLife.Cell));
        var b2 = std.mem.zeroes(Map(size, ConwaysGameOfLife.Cell));

        // Gosper glider gun
        ConwaysGameOfLife.setWorld(size, &.{
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
        }, &b2);

        var cgol = ConwaysGameOfLife.iterator(size, &b1, &b2);
        for (0..125) |_| {
            cgol.next();
            std.debug.print(clear_and_home ++ "{}", .{cgol});
            std.Thread.sleep(pause_for);
        }
    }
}

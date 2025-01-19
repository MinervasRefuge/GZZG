// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

// zig fmt: off

// 1k of "Hello World!\n" repeating.
const test_data = [_]u8{
    0x80, 0x08, 0x30, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57, 0x6f, 0x72,
    0x6c, 0x64, 0x21, 0x0a, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d,
    0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d,
    0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d,
    0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d, 0x00, 0xfe, 0x0d,
    0x00, 0xca, 0x0d, 0x00
};

const SnappyTagEnum = enum {literal, copy1, copy2, copy4};

const SnappyTag = packed union {
    literal: packed struct { tag: u2, len:  u6 },               // correct
    copy1:   packed struct { tag: u2, plen: u3, offset: u11 },
    copy2:   packed struct { tag: u2, len:  u6, offset: u16 }, //correct
    copy4:   packed struct { tag: u2, len:  u6, offset: u32 },
};

fn getSnappyTag(tag: * align(1) const SnappyTag) SnappyTagEnum {
    return switch (tag.literal.tag) {
        0 => .literal,
        1 => .copy1,
        2 => .copy2,
        3 => .copy4
    };
}

pub fn readULEB128(data: []const u8, idx: *usize) usize {
    var count: usize = 0;
    var shuffle:  u6 = 0;
    var out:   usize = 0;

    while ((count < @typeInfo(usize).Int.bits / 7) and (count < data.len)) : ({
        count   += 1;
        idx.*   += 1;
        shuffle += 7;
    }) {
        if ((data[idx.*] & 0b10000000) != 0) {
            out |= @as(usize, data[idx.*] & 0b01111111) << shuffle;
        } else {
            idx.* += 1;
            return out | (@as(usize, data[idx.*]) << shuffle);
        }
    }

    //fail here
    return out;
}

fn btoi(v: bool) u8 {
    if (v) {
        return 1;
    } else {
        return 0;
    }
}

const print = std.debug.print;


fn printSnappyTag(tag: * align(1) const SnappyTag) void {
    switch (getSnappyTag(tag)) {
        .literal => {
            const l = tag.literal;
            print("tag literal => len:{d}\n", .{l.len});
        },
        .copy1 => {
            const c1 = tag.copy1;
            print("tag copy1 => part_len:{d} offset:{d}\n", .{c1.part_len, c1.offset});
        },
        .copy2 => {
            const c2 = tag.copy2;
            print("tag copy2 => len:{d} offset:{d}\n", .{c2.len, c2.offset});
        },
        .copy4 => {
            const c4 = tag.copy4;
            print("tag copy4 => len:{d} offset:{d}\n", .{c4.len, c4.offset});
        }
    }
}

fn lazyCopy(src: [] const u8, dest: []u8, len: usize) void {
    var i: usize = 0;

    while (i < len) :(i += 1){
        dest[i] = src[i];
    }
}

fn peekBuffer(src: [] const u8) void {
    for (src) |v| {
        if (v > 0x20 and v < 0x7F) {
            print("{c: ^4} ", .{v});
        } else {
            print("0x{X:0<2} ", .{v});
        }
    }
    print("\n", .{});
}


fn decompressSnappy(allocator: std.mem.Allocator, data: [] const u8) ![]u8 {
    var in_idx: usize = 0;
    var out_idx: usize = 0;
    const ssz = readULEB128(data, &in_idx);
    print("ssz fin: {d}\n", .{in_idx});

    var out = try allocator.alloc(u8, ssz);
    
    while (true) {
        //peekBuffer(out);
        //const tag: *align(1) const SnappyTag = @alignCast(@ptrCast(data[in_idx..]));
        const tag = std.mem.bytesAsValue(SnappyTag, data[in_idx..]);
        //print("tag:{d}\n", .{tag.literal.tag});
        //print("@{d}@", .{in_idx});
        //printSnappyTag(tag);

        switch (getSnappyTag(tag)) {
            .literal => {
                const l = tag.literal;
                var len: usize = 1;

                //inc the size of the struct
                in_idx += 1;

                //print("tag literal => len:{d} {d} => {X:0>2}\n", .{l.len, in_idx, data[in_idx..in_idx+7]});
                
                switch (l.len) {
                    60 => {len += test_data[in_idx]; in_idx += 1;},
                    61 => {len += std.mem.bytesAsValue(u16, data[in_idx..]).*; in_idx += 2;},
                    62 => {len += std.mem.bytesAsValue(u24, data[in_idx..]).*; in_idx += 3;},
                    63 => {len += std.mem.bytesAsValue(u32, data[in_idx..]).*; in_idx += 4;},
                    else => {len += l.len;}
                }

                lazyCopy(data[in_idx..], out[out_idx..], len);
                     
                in_idx  += len;
                out_idx += len;
            },
            .copy1 => {
                const c1 = tag.copy1;
                
                print("tag copy1 => part_len:{d} offset:{d} {d} => {X:0>2}\n", .{c1.plen, c1.offset, in_idx, data[in_idx..in_idx+7]});
                in_idx += 2;
            },
            .copy2 => {
                const c2 = tag.copy2;
                const len = @as(usize, c2.len) + 1;

                //print("tag copy2 => len:{d} offset:{d} {d} => {X:0>2}\n", .{c2.len, c2.offset, in_idx, data[in_idx..in_idx+7]});

                lazyCopy(out[out_idx - c2.offset ..], out[out_idx..], len);
                
                in_idx  += 3;
                out_idx += len;
            },
            .copy4 => {
                const c4 = tag.copy4;
                
                const len = @as(usize, c4.len) + 1;
                //print("tag copy4 => len:{d} offset:{d} {d} => {X:0>2}\n", .{c4.len, c4.offset, in_idx, data[in_idx..in_idx+7]});

                lazyCopy(out[out_idx - c4.offset..], out[out_idx..], len);
                
                in_idx  += 5;
                out_idx += len;
            }
        }
        
        
        if (in_idx >= data.len or out_idx >= out.len) {
            break;
        }
    }
    
    return out;
}

pub fn main() !void {
    var   gpa        = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc      = gpa.allocator();
    var   idx: usize = 0;
    const ssz        = readULEB128(&test_data, &idx);

    print("uleb128 max bytes: {d}\n", .{@typeInfo(usize).Int.bits / 7});
    print("size:{d}(MB) => pos:{d} value 0x{X}\n", .{ ssz / 1024, idx, test_data[idx] });

    //const tag = std.mem.bytesAsValue(SnappyTagLiteral, test_data);

    //const tag: *align(1) const SnappyTag = @alignCast(@ptrCast(test_data[idx..]));

    //const olp = std.mem.bytesAsValue(SnappyTag, test_data[16..]);

    //print("overlay len:0x{b:0>6} => {d}, tag:0x{b:0>2}, offset: 0x{X:0>4}\n", .{olp.len, olp.len, olp.tag, olp.offset});
    //print("overlay 0x{b:0>8} len:0x{b:0>6} => {d}, tag:0x{b:0>2}, offset: 0x{b:0>16}\n",
     //     .{test_data[16..16+7], olp.copy2.len, olp.copy2.len, olp.copy2.tag, olp.copy2.offset});

    //print("{X} : {X}\n", .{@intFromPtr(&test_data[16]), @intFromPtr(test_data[16..].ptr)});
    
    const out = try decompressSnappy(alloc, &test_data);
    defer alloc.free(out);
}

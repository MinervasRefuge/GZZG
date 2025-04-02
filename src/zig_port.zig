// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std    = @import("std");
const gzzg   = @import("gzzg.zig");
const ports  = @import("port.zig"); // todo: should this be a direct import
const guile  = gzzg.guile;

const GZZGCustomPort = gzzg.contracts.GZZGCustomPort;

const ByteVector = gzzg.ByteVector;

const MakeCustomPort       = ports.MakeCustomPort;
const CustomPortSignatures = ports.CustomPortSignatures;
const RuntimeCustomPort    = ports.RuntimeCustomPort;
const Whence               = ports.Port.Whence;

// Using the "WriterAPI" as an example of testing for generic writer type...
// - ~GenericWriter~
//   - ~Error~ decl type
//   - ~context~ field
//   - /write/ fn
//   - /any/ fn
// - ~AnyWriter~
//   - ~Error~ decl type
//   - ~context~ field
//   - ~writeFn~ field
//   - /write/ fn
// - ~Buffered Writer~
//   - ~Error~ decl type
//   - ~Writer~ decl type
//   - /write/ fn
//   - /writer/ fn
// - ~Fixed Buffer Stream~
//   - ~WriteError~ decl type (due to ~ReadError~ and ~SeekError~)
//   - ~Writer~ decl type
//   - /write/ fn
//   - /writer/ fn
// - ~File~
//   - ~Writer~ decl type
//   - ~WriteError~ decl type
//   - /write/ fn
//   - /writer/ fn
// - ~CountingWriter~
//   - ~Error~ decl type
//   - ~Writer~ decl type
//   - /write/ fn
//   - /writer/ fn
// - ~MultiWriter~
//   - ~Error~ decl type
//   - ~Writer~ decl type
//   - /write/ fn
//   - /writer/ fn
// 
// So it should be possible to say that anything /writeable/ should have at least a ~write~ fn or a ~writer~
// with matching decl as ~GenericWriter~.
// 
// ~GenericWrite~ doesn't specialise anything and falls back to ~AnyWriter~.
// 
// #+begin_src zig
//   const Endian = std.buildin.Endian;
// 
//   pub inline fn write(self: Self, bytes: []const u8) Error!usize { }
//   pub inline fn writeAll(self: Self, bytes: []const u8) Error!void { }
//   pub inline fn print(self: Self, comptime format: []const u8, args: anytype) Error!void { }
//   pub inline fn writeByte(self: Self, byte: u8) Error!void { }
//   pub inline fn writeByteNTimes(self: Self, byte: u8, n: usize) Error!void { }
//   pub inline fn writeBytesNTimes(self: Self, bytes: []const u8, n: usize) Error!void { }
//   pub inline fn writeInt(self: Self, comptime T: type, value: T, endian: Endian) Error!void { }
//   pub inline fn writeStruct(self: Self, value: anytype) Error!void { }
//   pub inline fn writeStructEndian(self: Self, value: anytype, endian: Endian) Error!void { }
//   pub inline fn any(self: *const Self) AnyWriter { }
// #+end_src
//

fn isReadable(comptime T: type) bool {
    return @hasDecl(T, "read") or @hasDecl(T, "reader");
}

fn isWriteable(comptime T: type) bool {
    return @hasDecl(T, "write") or @hasDecl(T, "writer");
}

fn isSeekable(comptime T: type) bool {
    return @hasDecl(T, "seekableStream");
}

pub fn ZigIO(IO: type) type {
    return struct {
        enclasped: *IO,

        pub const name = "Zig: " ++ @typeName(IO);
        pub const RPort = RuntimeCustomPort(@This());

        pub const read  = if (isReadable(IO))  readFn  else noreturn;
        pub const write = if (isWriteable(IO)) writeFn else noreturn;
        pub const seek  = if (isSeekable(IO))  seekFn  else noreturn;
       
        fn readFn(port: RPort, dst: ByteVector, start: usize, count: usize) callconv(.c) usize {
            if (comptime !isReadable(IO)) @compileError("Not a Readable type: " ++ @typeName(RPort)); // is this even hittable?

            // read(self: *Self, dest: []u8) ReadError!usize
            if (comptime @hasDecl(IO, "reader")) {
                return port.get().enclasped.reader().read(dst.contents(u8)[start..][0..count]) catch {
                    @panic("Todo ReadError to guileError");
                };
            } else {
                return port.get().enclasped.read(dst.contents(u8)[start..][0..count]) catch {
                    @panic("Todo ReadError to guileError");
                };
            }
        }

        fn writeFn(port: RPort, src: ByteVector, start: usize, count: usize) callconv(.c) usize {
            if (comptime !isWriteable(IO)) @compileError("Not a Writeable type: " ++ @typeName(RPort)); // is this even hittable?
            
            // write(self: *Self, bytes: []const u8) WriteError!usize 
            if (comptime @hasDecl(IO, "writer")){
                return port.get().enclasped.writer().write(src.contents(u8)[start..][0..count]) catch {
                    @panic("Todo WriteError to guileError");
                };
            } else {
                return port.get().enclasped.write(src.contents(u8)[start..][0..count]) catch {
                    @panic("Todo WriteError to guileError");
                };
            }
        }
        
        fn seekFn(port: RPort, offset: guile.scm_t_off, whence: c_int) callconv(.c) guile.scm_t_off {
            if (comptime !isSeekable(IO)) @compileError("Not a Seekable type: " ++ @typeName(RPort)); // is this even hittable?

            const enclaspedSeek = port.get().enclasped.seekableStream();
            const w:Whence = @enumFromInt(whence);

            switch (w) {
                .current => {
                    enclaspedSeek.seekBy(offset) catch |err| {
                        @panic("Todo SeekError to guileError: " ++ @errorName(err));
                    };

                    return offset;
                },
                .end => @panic("Unimplemented"),
                .set => @panic("Unimplemented"),//enclaspedSeek.seekTo(offset) catch |err| { // scm_t_off is signed
                    //@panic("Todo SeekError to guileError: " ++ @errorName(err));
                //},
            }
        }
    };
}


pub fn WrapZigIO(IO: type) GZZGCustomPort(ZigIO(IO), type) {
    return MakeCustomPort(ZigIO(IO));
}

//
//
//

// result of using just create without setting encoding.
// Throw to key `encoding-error' with args `("put-char" "conversion to port encoding failed" 84 #<bogus: file 7f569cefea10> #\g)'.

test "guile port with wrapped FixBufferStream" {    
    gzzg.initThreadForGuile();

    const str = "großer";
    var out: [str.len] u8 = undefined;
    var buffer: [20] u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    var container: ZigIO(@TypeOf(stream)) = .{ .enclasped = &stream };
    var custom_port_type = WrapZigIO(@TypeOf(stream)).init();

    {
        const gport = custom_port_type.createWithEncoding(.{ .writable = true }, .fromUTF8("UTF-8"), &container);
        defer _ = gport.close();
        
        gport.putString(.fromUTF8(str), null, null);
    }

    try std.testing.expectEqual(stream.getPos() catch unreachable, str.len);
    try stream.seekTo(0);
    _ = try stream.read(&out);

    try std.testing.expectEqualStrings(str, &out);
}

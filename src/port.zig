// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const bopts = @import("build_options");
const guile = gzzg.guile;

const orUndefined = gzzg.orUndefined;

const Any        = gzzg.Any;
const Boolean    = gzzg.Boolean;
const ByteVector = gzzg.ByteVector;
const Number     = gzzg.Number;
const String     = gzzg.String;
const Symbol     = gzzg.Symbol;

//                                          ------------
//                                          Port §6.12.1
//                                          ------------

pub const Port = struct {
    s: guile.SCM,

    pub const guile_name = "port";
    
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_port_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }
    pub fn lowerZ(a: Port) Any { return .{ .s = a.s }; }

    pub fn isInput (a: Port) Boolean { return .{ .s = guile.scm_input_port_p(a.s) }; }
    pub fn isOutput(a: Port) Boolean { return .{ .s = guile.scm_output_port_p(a.s) }; }
    pub fn isClosed(a: Port) Boolean { return .{ .s = guile.scm_port_closed_p(a.s) }; }

    //

    pub fn close(a: Port) Boolean { return .{ .s = guile.scm_close_port(a.s) }; }

    pub const EOF = error{ EOF };

    // * DONE §6.12.2 Binary I/O                             :complete:allFunctions:
    //
    
    pub fn getU8(a: Port) EOF!Number {
        const data = Any{ .s = guile.scm_get_u8(a.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(Number);
    }

    pub fn lookaheadU8(a: Port) EOF!Number {
        const data = Any{ .s = guile.scm_get_u8(a.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(Number);
    }

    pub fn getByteVectorN(a: Port, count: Number) ByteVector {
        return .{ .s = guile.scm_get_bytevector_n(a.s, count.s) };
    }
    
    pub fn getByteVectorNX(a: Port, bv: ByteVector, start: Number, count: Number) EOF!Number {
        const data = Any{ .s = guile.scm_get_bytevector_n_x(a.s, bv.s, start.s, count.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(Number);
    }
   
    pub fn getByteVectorSome(a: Port) EOF!ByteVector {
        const data = Any{ .s = guile.scm_get_bytevector_some(a.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(ByteVector);
    }

    pub fn getByteVectorSomeX(a: Port, bv: ByteVector, start: Number, count: Number) EOF!Number {
        const data = Any{ .s = guile.scm_get_bytevector_some_x(a.s, bv.s, start.s, count.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(Number);
    }
  
    pub fn getByteVectorAll(a: Port) EOF!ByteVector {
        const data = Any{ .s = guile.scm_get_bytevector_all(a.s) };
        return if (data.isEOFZ()) error.EOF else data.raiseUnsafeZ(ByteVector);
    }

    pub fn ungetByteVector(a: Port, bv: ByteVector, start: ?Number, count: ?Number) void {
        _ = guile.scm_unget_bytevector(a.s, bv.s, orUndefined(start), orUndefined(count));
    }

    pub fn putU8(a: Port, octet: Number) void {
        _ = guile.scm_put_u8(a.s, octet.s);
    }

    pub fn putByteVector(a: Port, bv: ByteVector, start: ?Number, count: ?Number) void {
        _ = guile.scm_put_bytevector(a.s, bv.s, orUndefined(start), orUndefined(count));
    }
        
    // * DONE §6.12.3 Encoding                             :complete:allFunctions:
    // 

    pub fn encoding   (a: Port)              String { return .{ .s = guile.scm_port_encoding(a.s) }; }
    pub fn setEncoding(a: Port, enc: String) void   { _ = guile.scm_set_port_encodingx_x(a.s, enc.s); }
    
    pub const ConversionStrategy = enum {
        const cache = gzzg.StaticCache(Symbol, std.meta.fieldNames(@This()));
        
        @"error",
        substitute,
        escape,

        pub fn get(a: @This()) Symbol {
            return switch(a) {
                inline else => |t| cache.get(@tagName(t))
            };
        }

        pub fn to(a: Symbol) ?@This() {
            inline for(std.meta.fields(@This())) |field| {
                if (gzzg.eqZ(cache.get(field.name), a))
                    return @enumFromInt(field.value);
            }

            return null;
        }
    };

    pub fn conversionStrategy(a: ?Port) ConversionStrategy { 
        const p = if (a != null) a.s else Boolean.FALSE.s;
        return .to(.{ .s = guile.scm_port_conversion_strategy(p) }).?; 
    }

    pub fn setConversionStrategy(a: ?Port, cs: ConversionStrategy) void {
        const p = if (a != null) a.s else Boolean.FALSE.s;
        guile.scm_set_port_conversion_strategy(p, cs.get());
    }

    // * TODO §6.12.4 Textual I/O                          :incomplete:allFunctions:
    //

    // scm_port_column (port)
    // scm_port_line (port)
    // scm_set_port_column_x (port, column)
    // scm_set_port_line_x (port, line)
    
    // * DONE §6.12.6 Buffering                            :complete:allFunctions:
    // 

    pub const BufferingMode = union(enum) {
        const cache = gzzg.StaticCache(Symbol, std.meta.fieldNames(@This()));
        
        none,
        line,
        block:?Number,

        pub fn get(a: @This()) Symbol {
            return switch(a) {
                inline else => |t| cache.get(@tagName(t))
            };
        }
    };

    pub fn setvbuf(a: Port, mode: BufferingMode) void {
        const size = if (mode == .block) mode.block else null;
        guile.scm_setvbuf(a.s, mode.get().s, orUndefined(size));
    }

    pub fn forceOutput  (a: Port) void { _ = guile.scm_force_output(a.s); }
    pub fn flushAllPorts()        void { _ = guile.scm_flush_all_ports(); }
    pub fn drainInput   (a: Port) String { return .{ .s = guile.scm_drain_input(a.s) }; }

    // * DONE §6.12.7 Random Access                        :complete:allFunctions:
    // 

    pub const Whence = enum(u2) {
        // Guile uses the same values are ~fseek~
        const S = std.os.linux.SEEK;
        
        set     = S.SET,
        current = S.CUR,
        end     = S.END,

        // Integer
        pub fn toNumber(a: @This()) Number {
            return .from(@intFromEnum(a));
        }
    };

    //todo Integer
    pub fn seek(a: Port, offset: Number, whence: Whence) Number { return .{ .s = guile.scm_seek(a.s, offset.s, whence.toNumber()) }; }
    pub fn ftell(a: Port) Number { return .{ .s = guile.scm_ftell(a.s) }; }
    pub fn truncateFile(a: Port, length: ?Number) void { guile.scm_truncate_file(a.s, orUndefined(length)); }

    // * DONE §6.12.9 Default Ports                          :complete:allFunctions:
    // 

    pub fn currentInput () Port { return .{ .s = guile.scm_current_input_port () }; }
    pub fn currentOutput() Port { return .{ .s = guile.scm_current_output_port() }; }
    pub fn currentError () Port { return .{ .s = guile.scm_current_error_port () }; }

    pub fn setCurrentInput (a: Port) void { _ = guile.scm_set_current_input_port (a.s); }
    pub fn setCurrentOutput(a: Port) void { _ = guile.scm_set_current_output_port(a.s); }
    pub fn setCurrentError (a: Port) void { _ = guile.scm_set_current_error_port (a.s); }

    pub fn dynwindCurrentInput (a: Port) void { guile.scm_dynwind_current_input_port (a.s); }
    pub fn dynwindCurrentOutput(a: Port) void { guile.scm_dynwind_current_output_port(a.s); }
    pub fn dynwindCurrentError (a: Port) void { guile.scm_dynwind_current_error_port (a.s); }

    // * TODO §6.12.10 Type of Ports                                    :incomplete:
    // 

    // * DONE §6.12.12 Using Ports from C                  :complete:allFunctions:
    // 

    pub fn readZ (a: Port, buffer: []u8)       usize { return guile.scm_c_read (a.s, buffer.ptr, buffer.len); }
    pub fn writeZ(a: Port, buffer: []const u8) void  {        guile.scm_c_write(a.s, buffer.ptr, buffer.len); }

    pub fn readBytesZ(a: Port, bv: ByteVector, start: usize, count: usize) usize
        { return guile.scm_c_read_bytes(a.s, bv.s, start, count); }
    
    pub fn writeBytesZ(a: Port, bv: ByteVector, start: usize, count: usize) void
        { guile.scm_c_write_bytes(a.s, bv.s, start, count); }

    pub fn ungetBytesZ(a: Port, buffer:[]u8) void { guile.scm_unget_bytes(buffer.ptr, buffer.len, a.s); }
    pub fn ungetByteZ (a: Port, byte: u8)    void { guile.scm_unget_byte(byte, a.s); } 
    
    // todo: is it i32/u32 or u21?
    pub fn ungetC(a: Port, c: i32) void { guile.scm_ungetc(c, a.s); }
    pub fn putLatin1(a: Port, buffer: []const u8)  void { guile.scm_c_put_latin1_chars(a.s, buffer.ptr, buffer.len); }
    pub fn putUTF32 (a: Port, buffer: []const u32) void { guile.scm_c_put_utf32_chars (a.s, buffer.ptr, buffer.len); }

    // Extra?

    pub fn flush(a: Port) void { guile.scm_flush(a.s); }
    
    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};


// * TODO 6.12.13 Implementing New Port Types in C                   :undecided:

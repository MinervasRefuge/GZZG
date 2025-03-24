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
        
    // * TODO §6.12.3 Encoding                             :incomplete:allFunctions:
    //

    // scm_port_encoding (port)
    // scm_set_port_encoding_x (port, enc)
    // scm_port_conversion_strategy (port)
    // scm_set_port_conversion_strategy_x (port, sym)

    // * TODO §6.12.4 Textual I/O                          :incomplete:allFunctions:
    //

    // scm_port_column (port)
    // scm_port_line (port)
    // scm_set_port_column_x (port, column)
    // scm_set_port_line_x (port, line)
    
    // * TODO §6.12.6 Buffering                            :incomplete:allFunctions:
    //

    // scm_setvbuf (port, mode, size)
    // scm_force_output (port)
    // scm_flush_all_ports ()
    // scm_drain_input (port)

    // * TODO §6.12.7 Random Access                        :incomplete:allFunctions:
    //

    // scm_seek (fd_port, offset, whence)
    // scm_ftell (fd_port)
    // scm_truncate_file (file, length)

    // * TODO §6.12.9 Default Ports                       :incomplete:allFunctions:

    pub fn currentInput () Port { return .{ .s = guile.scm_current_input_port () }; }
    pub fn currentOutput() Port { return .{ .s = guile.scm_current_output_port() }; }
    pub fn currentError () Port { return .{ .s = guile.scm_current_error_port () }; }

    // scm_set_current_input_port (port)
    // scm_set_current_output_port (port)
    // scm_set_current_error_port (port)

    // void scm_dynwind_current_input_port (SCM port)
    // void scm_dynwind_current_output_port (SCM port)
    // void scm_dynwind_current_error_port (SCM port)

    // * TODO §6.12.10 Type of Ports                                    :incomplete:
    // 

    // * TODO §6.12.12 Using Ports from C                  :incomplete:allFunctions:
    //

    // size_t scm_c_read (SCM port, void *buffer, size_t size)
    // void scm_c_write (SCM port, const void *buffer, size_t size)
    // size_t scm_c_read_bytes (SCM port, SCM bv, size_t start, size_t count)
    // void scm_c_write_bytes (SCM port, SCM bv, size_t start, size_t count)
    // void scm_unget_bytes (const unsigned char *buf, size_t len, SCM port)
    // void scm_unget_byte (int c, SCM port)
    // void scm_ungetc (scm_t_wchar c, SCM port)
    // void scm_c_put_latin1_chars (SCM port, const scm_t_uint8 *buf, size_t len)
    // void scm_c_put_utf32_chars (SCM port, const scm_t_uint32 *buf, size_t len)
    
    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};


// * TODO 6.12.13 Implementing New Port Types in C                   :undecided:

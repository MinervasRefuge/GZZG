// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const UnionOf = gzzg.UnionOf;

const GZZGTypes = gzzg.contracts.GZZGTypes;

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const ListOf  = gzzg.ListOf;
const Port    = gzzg.Port;
const String  = gzzg.String;

pub const SimpleFormatZ = union(enum) {
    display: guile.SCM,
    write: guile.SCM,
    
    // there are two ways to go about writing guile values to the writer.
    // custom port wrapper via writer using comptime. (generic or AnyWriter impl)
    // or...
    // String Port in and out (or string iterator).
    // .
    // .
    // neither are "optimal"
    // ----
    // String Ports are used in this implementation.
    pub fn format(value: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        
        const vstr = init: {
            const bstr = Port.string_port.openOutput();
            defer _ = bstr.close();
            
            switch (value) {
                .display => |g| _ = guile.scm_display(g, bstr.s),
                .write   => |g| _ = guile.scm_write(g, bstr.s),
            }
            
            break :init Port.string_port.getOutputString(bstr);
        };

        // 50:50 between implementation choices

        // var itr = vstr.iterator();
        // 
        // while (itr.next()) |c| {
        //     const cs = try c.toZ();
        //     try writer.writeAll(cs.getConst());
        // }

        const p = Port.string_port.openInput(vstr);
        defer _ = p.close();
        
        var io = std.fifo.LinearFifo(u8, .{ .Static = 256 }).init();  // todo: how big really is needed? 4096
        io.pump(p.reader(), writer) catch |err| return switch (err) {
            error.IsntReadable,
            error.Closed => error.Unexpected,
            else => |e| e,
        };
    }
};

fn simpleFormatCount(comptime message: []const u8) comptime_int {
    var msg = message;
    var idx_arg = 0;
    
    while (std.mem.indexOfScalar(u8, msg, '~')) |idx| {
        switch (msg[idx+1]) {
            '~' => {},
            else => idx_arg += 1,
        }
        msg = msg[idx+2..];
    }

    return idx_arg;
}

/// std.fmt.format like formater for Guile type using ~S for `write`, ~A for `display`
pub fn simpleFormatZ(writer: anytype, comptime message: []const u8, args: anytype) GZZGTypes(@TypeOf(args), @TypeOf(writer).Error!void) {
    //todo there are more error checks worth doing.
    comptime var fmt:[]const u8 = "";
    const INA = std.meta.Tuple(&[1]type{SimpleFormatZ} ** simpleFormatCount(message));
    var ina:INA = undefined;

    comptime var msg = message;
    comptime var idx_arg = 0;
    
    inline while (comptime std.mem.indexOfScalar(u8, msg, '~')) |idx| {
        comptime var key = "{}";

        if (idx_arg >= args.len) @compileError("More formaters than args");

        switch (msg[idx+1]) {
            'a', 'A' => {
                ina[idx_arg] = .{ .display = args[idx_arg].s };
                idx_arg += 1;
            },
            's', 'S' => {
                ina[idx_arg] = .{ .write = args[idx_arg].s };
                idx_arg += 1;
            },
            '~' => {
                key = "{c}";
                ina = ina ++ .{'~'};
            },
            else => @compileError("Unknown format op: " ++ fmt[idx..idx+2]),
        }
        
        comptime fmt = fmt ++ msg[0..idx] ++ key;
        msg = msg[idx+2..];
    }

    fmt = fmt ++ msg;

    if (idx_arg != args.len) @compileError("More args than formaters");

    //

    try std.fmt.format(writer, fmt, ina);
}

// §6.12.5 Simple Textual Output
pub fn simpleFormat(destination: UnionOf(.{ Port, Boolean }), msg: String, args: ListOf(Any)) ?String {
    const out = guile.scm_simple_format(destination.s, msg.s, args.s);

    return if (String.isZ(out)) .{ .s = out } else null;
}




// ===============================================================================
// Not implement as of current due the size of options.
// But commented for the sake of keeping current work around.
// ===============================================================================

// // https://www.lispworks.com/documentation/HyperSpec/Body/f_format.htm
// // https://www.lispworks.com/documentation/HyperSpec/Body/22_c.htm


// // * Common Lisp HyperSpec - §22.3 Formatted Output




// pub fn format(writer: anytype, comptime control_string: []const u8, args: anytype)
//     FormatOver(@TypeOf(writer), control_string, @TypeOf(args), !void)
// {
        
// }

// pub fn FormatOver(Writer: type, comptime control_string:[] const u8, Args: type, Output: type) type {
//     _ = Writer;
//     _ = control_string;
//     _ = Args;
//     return Output;
// }

// // ** Control Specifiers
// // ***  §22.3.1 FORMAT Basic Output
// // ~C
// // ~%
// // ~&
// // ~|
// // ~~
// //
// // *** §22.3.2 FORMAT Radix Control
// // ~R
// // ~D
// // ~B
// // ~O
// // ~X
// // *** §22.3.3 FORMAT Floating-Point Printers
// // ~F
// // ~E
// // ~G
// // ~$
// //
// // *** §22.3.4 FORMAT Printer Operations
// // ~A
// // ~S
// // ~W
// //
// // *** §22.3.5 FORMAT Pretty Printer Operations
// // ~_
// // ~<
// // ~I
// // ~/
// //
// // *** §22.3.6 FORMAT Layout Control
// // ~T
// // ~<
// // ~>
// //
// // *** §22.3.7 FORMAT Control-Flow Operations
// // ~*
// // ~[
// // ~]
// // ~{
// // ~}
// // ~?
// //
// // *** §22.3.8 FORMAT Miscellaneous Operations
// // ~(
// // ~)
// // ~P
// //
// // *** §22.3.9 FORMAT Miscellaneous Pseudo-Operations
// // ~;
// // ~^
// // ~\n
// //
// // *** §22.3.10 Additional Information about FORMAT Operations
// // 22.3.10.1 Nesting of FORMAT Operations
// // *** §22.3.11 Examples of FORMAT
// // *** §22.3.12 Notes about FORMAT




// // Slice a directive in a /control string/
// // fn sliceDirective(start: []const u8)  {
// //     
// // }

// const Directive = union(enum) {
//     newline: Newline,

//     asthetic: Aesthetic,

//     decimal: Decimal,


//     // pub fn sliceDirective(start: []const u8) @This() {
//     //     var quote: bool = false;
//     //     var directive: ?u8 = null;
//     //     
//     //     var idx:usize = 0;
//     //     while (idx < start.len) : (idx += 1) {
//     //         switch (start[idx]) {
//     //             '0'...'9',
//     //             ':', '@', ',', => {
//     //                 quote = false;
//     //                 continue;
//     //             },
//     //             '\'' => {
//     //                 quote = true;
//     //                 continue;
//     //             },
//     //             'a'...'z',
//     //             'A'...'Z' => |c| {
//     //                 if (quote) {
//     //                     quote = false;
//     //                     continue;
//     //                 }
//     // 
//     //                 
//     //             },
//     //         }
//     //     }
//     // }

//     pub fn sliceDirective(start: []const u8) @This() {
//         var at = false;
//         var colon = false;
//         var arg_idx = 0;
//         var arg_start = 0;
//         const args: [5]?[]const u8 = [1]?[]const u8{null} ** 5;

//         var idx:usize = 0;

//         const state = switch (c) {
//             ',' => .end_arg,
//             'a'...'z', 'A'...'Z', '%' => .directive,
//             '0'...'9' => .arg_number,
//             '\'' => .arg_quote,
//             ':' => .colon_to_end,
//             '@' => .at_to_end,
//             else => @panic("Unknown start char")
//         };


//         // todo: expand valid directive tag match
//         next: switch (state) {
//             .end_arg  => { 
//                 const len = idx - arg_start;
                
//                 args[arg_idx] = if (len > 1) start[arg_start..idx] else null;
//                 arg_start = idx;
//                 arg_idx += 1;
//                 // todo check arg_idx count

//                 if (start[idx] == ',') { // zero sized field
//                     idx += 1;
//                 }

//                 continue :next switch (start[idx]) {
//                     ',' => .end_arg,
//                     'a'...'z', 'A'...'Z', '%' => .directive,
//                     '0'...'9' => .arg_number,
//                     '\'' => .arg_quote,
//                     ':' => .colon_to_end,
//                     '@' => .at_to_end,
//                     else => @panic("Unknown start char")
//                 };
//             },
            
//             .arg_number => {
//                 idx += 1;

//                 continue :next switch (start[idx]) {
//                     ':', '@', ',', 'a'...'z', 'A'...'Z', '%' => .end_arg,
//                     '0'...'9' => .arg_number,
//                     else => @panic("ASDF")
//                 };
//             },

//             .arg_quote => { // quoted single char
//                 idx += 1;
//                 arg_start = idx;

//                 idx += 1;
                
//                 continue :next switch (start[idx]) {
//                     ',', ':', '@', 'a'...'z', 'A'...'Z', '%' => .end_arg,
//                     else => @panic("ASDFs")
//                 };
//             },
            
//             .colon_to_end => {
//                 colon = true;
//                 idx += 1;
//                 continue :next switch (start[idx]) {
//                     'a'...'z', 'A'...'Z', '%' => .directive,
//                     '@' => .colon_followed_by_at,
//                     else => @panic("Expected @ or Directive")
//                 };
//             },

//             .colon_followed_by_at => {
//                 at = true;
//                 idx += 1;
//                 continue :next switch (start[idx]) {
//                     'a'...'z', 'A'...'Z', '%' => .directive,
//                     else => @panic("Expected Directive")
//                 };
//             },

//             .at_to_end => {
//                 at = true;
//                 idx += 1;
//                 continue :next switch (start[idx]) {
//                     'a'...'z', 'A'...'Z', '%' => .directive,
//                     ':' => .at_followed_by_colon,
//                     else => @panic("Expected : or Directive")
//                 };
//             },

//             .at_followed_by_colon => {
//                 colon = true;
//                 idx += 1;
//                 continue :next switch (start[idx]) {
//                     'a'...'z', 'A'...'Z', '%' => .directive,
//                     else => @panic("Expected Directive")
//                 };
//             },
            
//             .directive => {
//                 return matchDirective(start[idx], &args, colon, at);
//             },
//         }
//     }

//     fn matchDirective(d: u8, args:[]?[]const u8, colon: bool, at: bool) Directive {
//         @panic("Unimplemented");
//     }

//     const State = enum {
//         start,
//         arg,
//         arg_quote,
//         end_arg,
//         colon_to_end,
//         colon_followed_by_at,
//         at_to_end,
//         at_followed_by_colon,
//         directive
//     };

//     /// ~n%
//     const Newline = struct {
//         const directive = '%';
        
//         count: usize,

//         fn from(slice: []const u8) @This() {
            
//         }
//     };

//     /// ~mincol,colinc,minpad,padcharA
//     const Aesthetic = struct {
//         const directive = 'A';
        
//         nil_flag: bool = false,        // :
//         alignment: Alignment = .right, // @
        
//         min_columns: usize = 0,        // mincol
//         insert_multiples: usize = 1,   // colinc
//         min_copies: usize = 0,         // minpad
//         pad: u8 = ' ',       
//     };

//     /// ~mincol,padchar,commachar,comma-intervalD
//     const Decimal = struct {
//         const directive = 'D';
        
//         group: bool = false,    // :
//         sign: bool = false,     // @
        
//         min_columns: usize = 0, // mincol
//         pad: u8 = ' ',          // padchar
//         separator: u8 = ',',    // commachar
//         interval: usize = 3,    // comma-interval
//     };

//     const Alignment = enum { left, right };
// };




// // const Directive = struct {
// //     first: ?[]const u8,
// //     second: ?[]const u8,
// //     third: ?[]const u8,
// //     forth: ?[]const u8,
// //     fifth: ?[]const u8,
// //     colon: bool,
// //     at: bool,
// // 
// //     kind: Kind,
// // 
// // 
// // 
// //     const Kind = enum {
// //         charactor = 'C',
// //         new_line = '%',
// // //        radix = 'R',
// //         decimal = 'D',
// // //        binary = 'B',
// // //        octal = 'O',
// //         hexadecimal = 'X',
// //         aesthetic = 'A',
// //         standard = 'S',
// //         write = 'W',
// //     };
// // };

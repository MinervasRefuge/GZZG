// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg");

const display      = gzzg.display;
const newline      = gzzg.newline;
const simpleFormat = gzzg.fmt.simpleFormat;

const Any       = gzzg.Any;
const List      = gzzg.List;
const ListOf    = gzzg.ListOf;
const Number    = gzzg.Number;
const Port      = gzzg.Port;
const Procedure = gzzg.Procedure;
const String    = gzzg.String;
const Symbol    = gzzg.Symbol;


pub fn main() !void {
    gzzg.initThreadForGuile();

    const out_port = Port.current.output();
    const scmstr  = String.fromUTF8("Hello World!");
    const scmstr2 = String.fromUTF8("And again but different string!");

    display(scmstr);
    newline();
    _ = simpleFormat(.into(out_port), scmstr2, List.init(.{}));

    // This is similar as the above two simpleFormat and display
    try out_port.writer().writeAll("For a third time!");
    newline();

    // Sum numbers
    const na = Number.from(54321);
    const nb = Number.from(432.665);
    const no = na.sum(nb);

    display(no);
    newline();
    display(Number.from(30).sum(.from(12)));
    newline();

    // display a list of numbers
    const lst = gzzg.List.init(.{ Number.from(5), Number.from(1) });
    display(lst);
    newline();

    // same goes for list of strings
    const los = ListOf(String).init(.{ String.fromUTF8("a"), String.fromUTF8("b") });
    display(los);
    newline();

    // These two are only eq because of being inside fix num size
    std.debug.assert(gzzg.eqZ(Number.from(5), Number.from(5)));

    // These two are compared with the right method
    std.debug.assert(Number.from(5).equal(.from(5)).toZ());
    
    // Try a capture an error that could fail.
    if (divide(gzzg.Number.from(5), gzzg.Number.from(0))) |v| {
        std.debug.print("Won't get here: {}\n", .{v});
    } else |_| {
        std.debug.print("error: div zero caught\n", .{});
    }
    
    // register a custom Guile thunk
    const dbz = Procedure.define(
        "div-by-zero",
        divideByZero,
        "Test of raise exceptions from a zig error",
        false
    );

    std.debug.print("Time to long jmp away!\n", .{});
    
    // This will trigger a long job from the ~divideByZero()~ fn and cause the program to exit.
    _ = dbz.call(.{});

    std.debug.print("This line will never be run.\n", .{});
}

fn divideByZero() Number {
    const a = Number.from(10).divide(.from(0)); // long jmp from HEEEeeeaaarrrr.r.r...
    
    return a.sum(.from(2));
}

/// Divide by zero safe function
fn divide(a: Number, b: ?Number) !Number {
    var out: error{numericalOverflow}!Number = undefined;
    const captures = .{ a, b, &out };
    const Captures = @TypeOf(captures);

    gzzg.catchException("numerical-overflow", Captures, &captures, struct {
        pub fn body(data: *const Captures) void {
            data[2].* = data[0].divide(data[1]);
        }

        pub fn handler(data: *const Captures, _: Symbol, _: Any) void {
            data[2].* = error.numericalOverflow;
        }
    });

    return out;
}

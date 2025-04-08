// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg");
const guile = gzzg.guile;

const simpleFormat  = gzzg.fmt.simpleFormat;
const simpleFormatZ = gzzg.fmt.simpleFormatZ;

const Integer   = gzzg.Integer;
const List      = gzzg.List;
const Number    = gzzg.Number;
const Port      = gzzg.Port;
const Procedure = gzzg.Procedure;
const String    = gzzg.String;

const guile_monte_carlo_pi = \\
    \\ (define (monte-carlo-pi samples)
    \\   (set! *random-state* (random-state-from-platform))
    \\
    \\   (define in 0)
    \\ 
    \\   (let lp ((remaining samples))
    \\     (if (<= remaining 0)
    \\         (* 4 (/ in samples))
    \\         (let ((x (random:uniform))
    \\               (y (random:uniform)))
    \\           (when (<= (+ (expt x 2)
    \\                        (expt y 2))
    \\                   1.0)
    \\               (set! in (1+ in)))
    \\           (lp (1- remaining))))))
    \\ 
    \\ monte-carlo-pi
;

pub fn zigMonteCarloPi(comptime T: type, samples: usize) Ratio {
    switch (@typeInfo(T)) {
        .float => {},
        else => @compileError("Expect float type got: " ++ @typeName(T)),
    }

    const pow     = std.math.pow;
    var generator = std.Random.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));
    var rand      = generator.random();

    var in: usize = 0;
    var i:  usize = 0;
    while (i <= samples) : (i += 1)  {
        const x:T = rand.float(T);
        const y:T = rand.float(T);
        const xpy = pow(T, x, 2) + pow(T, y, 2);

        if (xpy <= 1.0) {
            in += 1;
        }
    }

    return .init(in*4, samples);
}

pub fn gzzgMonteCarloPi(samples: usize) Number {
    const two               = Number.from(2);
    const quart_unit_circle = Number.from(1.0);
    const rand              = Number.RandomState.fromPlatform();

    var in       = Number.from(0);
    var i: usize = 0;
    while (i <= samples) : (i += 1)  {
        const x = Number.randomUniform(rand); 
        const y = Number.randomUniform(rand);

        if (x.expt(two).sum(y.expt(two)).lessThanEqual(quart_unit_circle).toZ()) {
            in = in.onePlus();
        }
    }

    return in.divide(.from(samples)).product(.from(4));
}

// h^2 = a^2 + b^2
// h^2 = 2a^2
// fit 2a^2 in the range of a fixed num;
fn maxRadius() comptime_int {
    const FixNum = gzzg.internal_workings.FixNum;
    
    const hypt = @as(comptime_float, std.math.maxInt(FixNum)); // h^2
    const apt  = hypt / 2.0; // rem: a^2
    
    return @trunc(@sqrt(apt)); 
}

pub fn gzzgMonteCarloPiFixNum(samples: usize) Number {
    const isFixNum = gzzg.internal_workings.isFixNum;
    const toIW     = gzzg.internal_workings.gSCMtoIWSCM;
    
    const max               = Number.from(comptime maxRadius());
    const two               = Number.from(2);
    const rand              = Number.RandomState.fromPlatform();
    const quart_unit_circle = max.expt(two);
    
    var in       = Number.from(0);
    var i: usize = 0;
    while (i <= samples) : (i += 1)  {
        const x   = max.random(rand);
        const y   = max.random(rand);
        const xpy = x.expt(two).sum(y.expt(two));
        
        std.debug.assert(isFixNum(toIW(x.s)));
        std.debug.assert(isFixNum(toIW(y.s)));
        std.debug.assert(isFixNum(toIW(xpy.s)));

        if (xpy.lessThanEqual(quart_unit_circle).toZ()) {
            in = in.onePlus();
        }
    }

    return in.divide(.from(samples)).product(.from(4));
}


// toilet -f pagga | boxes --design whirly -a c
//  .+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.
// (                                                                 )
//  )   ░█▄█░█▀█░█▀█░▀█▀░█▀▀░░░█▀▀░█▀█░█▀▄░█░░░█▀█░░░░░░░█▀█░▀█▀    (
// (    ░█░█░█░█░█░█░░█░░█▀▀░░░█░░░█▀█░█▀▄░█░░░█░█░░▀░░░░█▀▀░░█░     )
//  )   ░▀░▀░▀▀▀░▀░▀░░▀░░▀▀▀░░░▀▀▀░▀░▀░▀░▀░▀▀▀░▀▀▀░░▀░░░░▀░░░▀▀▀    (
// (                                                                 )
//  "+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"+.+"

pub fn main() !void {
    const samples = getSamplesFromArgs();
    const out = std.io.getStdOut();
    
    try out.writer().print("Monte Carlo: Pi - Samples:{d}\n\n", .{samples});
    defer out.writer().print("Fin.\n", .{}) catch {};
    
    gzzg.initThreadForGuile();

    const thread_result1 = try std.Thread.spawn(.{}, threadResult1, .{samples});      // scheme_monte_carlo_PI
    defer thread_result1.join();
    const thread_result2 = try std.Thread.spawn(.{}, threadResult2, .{samples});      // gzzgMonteCarloPI
    defer thread_result2.join();
    const thread_result3 = try std.Thread.spawn(.{}, threadResult3, .{samples});      // gzzgMonteCarloPIFixNum
    defer thread_result3.join();
    const thread_result4 = try std.Thread.spawn(.{}, threadResult4, .{f64, samples}); // zigMonteCarloPI
    defer thread_result4.join();
}

var xout: std.Thread.Mutex = .{};

//todo: consider a ~gzzg.fmt~ tool

fn threadResult1(samples: usize) void {
    gzzg.initThreadForGuile();
    const gmonte_carlo_pi = gzzg.eval(guile_monte_carlo_pi, null).raiseZ(Procedure).?;
    const result = gmonte_carlo_pi.call(.{ Number.from(samples) }).raiseZ(Number).?;

    xout.lock();
    defer xout.unlock();
    {
        const out = std.io.getStdOut().writer();

        simpleFormatZ(out, "Guile eval:\n~A\n~A\n\n", .{result, result.exactToInexact()}) catch {};
    }
}

fn threadResult2(samples: usize) void {
    gzzg.initThreadForGuile();
    const result = gzzgMonteCarloPi(samples);

    xout.lock();
    defer xout.unlock();
    {
        // native simple-format usage
        _ = simpleFormat(
            .into(Port.current.output()), 
            .fromUTF8("GZZG Float:\n~A\n~A\n\n"), 
            .init(.{ result.lowerZ(), result.exactToInexact().lowerZ() })
        );
    }
}

fn threadResult3(samples: usize) void {
    gzzg.initThreadForGuile();
    const result = gzzgMonteCarloPiFixNum(samples);

    xout.lock();
    defer xout.unlock();
    {
        const out = std.io.getStdOut().writer();
        
        simpleFormatZ(out, "GZZG Fixed Num:\n~A\n~A\n\n", .{result, result.exactToInexact()}) catch {};
    }
}

fn threadResult4(comptime T: type, samples: usize) void {
    var result = zigMonteCarloPi(T, samples);
    result.revise();

    xout.lock();
    defer xout.unlock();
    {
        const out = std.io.getStdOut();   
        out.writer().print("Zig f64:\n{}\n{d:.7}\n\n", .{result, result.as(f64)}) catch unreachable;
    }
}

//

fn getSamplesFromArgs() usize {
    var samples:usize = 10_000;

    var idx:usize = 0;
    var itr = std.process.args();
    while (itr.next()) |arg| : (idx += 1) {
        if (idx == 1) {
            samples = std.fmt.parseInt(usize, arg, 10) catch {
                @panic("Unknown size provided");
            };

            break;
        }
    }
    
    return samples;
}

const Ratio = struct {
    numerator: usize,
    denominator: usize,

    pub fn init(n: usize, d: usize) Ratio {
        return .{
            .numerator = n,
            .denominator = d,
        };
    }

    pub fn revise(self: *@This()) void {
        const l = std.math.gcd(self.numerator, self.denominator);

        self.* = .{
            .numerator = @divExact(self.numerator, l),
            .denominator = @divExact(self.denominator, l),
        };
    }

    pub fn as(self: Ratio, T: type) T {
        switch (@typeInfo(T)) {
            .float => {},
            else => @compileError("Expect float type got: " ++ @typeName(T)),
        }

        const n: T = @floatFromInt(self.numerator);
        const d: T = @floatFromInt(self.denominator);

        return n / d;
    }

    pub fn format(value: Ratio, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}/{d}", .{value.numerator, value.denominator});
    }
};

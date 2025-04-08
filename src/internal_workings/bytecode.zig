// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("../gzzg.zig");
const bopts = @import("build_options");

const Any        = gzzg.Any;
const ByteVector = gzzg.ByteVector;
const Port       = gzzg.Port;
const Procedure  = gzzg.Procedure;


pub const Bytecode = packed struct {
    directive: Directive,
    operand: Operand,

    /// comptime categories of the directives
    fn categoriseDirectives() struct { varlen: []Directive, regular:[]Directive, noop: []Directive} {
        @setEvalBranchQuota(60_000);

        const Backing   = @typeInfo(Bytecode.Directive).@"enum".tag_type;
        const max       = std.math.maxInt(Backing);

        var varlen  = std.BoundedArray(Directive, max){};
        var regular = std.BoundedArray(Directive, max){};
        var noop    = std.BoundedArray(Directive, max){};

        next: for (0..max) |idx_directive| {
            const directive: Directive = @enumFromInt(idx_directive);

            if (std.enums.tagName(Directive, directive)) |name| {
                for (std.meta.fields(@FieldType(Operand, name))) |field| {  // lp over structs
                    if (field.type == VariableLengthOperand) {
                        varlen.append(directive) catch @compileError("Oh No");
                        continue :next;
                    }
                }

                regular.append(directive) catch @compileError("Oh No");

            } else {
                noop.append(directive) catch @compileError("Oh No");
            }
        }

        return .{
            .varlen  = varlen .slice(),
            .regular = regular.slice(),
            .noop    = noop   .slice(),
        };
    }

    /// gets the full op width (inc. directive)
    pub fn getWidth(op: *const align(1) @This()) usize {
        const categories = comptime categoriseDirectives();
        
        inline for (categories.regular) |d| 
            if (d == op.directive) return @divExact(@bitSizeOf(@FieldType(Operand, @tagName(d))), 8) + 1;
        
        inline for (categories.varlen) |d| { // should only ever be one instruction and the last operand var len
            if (d == op.directive) {
                var bits:usize = @divExact(@bitSizeOf(@FieldType(Operand, @tagName(d))), 8) + 1;
                
                inline for (std.meta.fields(@FieldType(Operand, @tagName(d)))) |field| {
                    if (field.type == VariableLengthOperand) {
                        bits += @field(@field(op.operand, @tagName(d)), field.name).lenBytes();
                    }
                }

                return bits;
            }            
        }

        // categories.noop
        @panic("Unknown instruction");
    }

    pub fn format(value: Bytecode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const categories = comptime categoriseDirectives();

        inline for (categories.regular ++ categories.varlen) |d| {
            if (d == value.directive) {
                const name = @tagName(d);
                const operand_fields = comptime std.meta.fields(@FieldType(Operand, name));

                try writer.print("{s}{{", .{ name });
            
                inline for (operand_fields, 0..) |operand_field, idx| {
                    if (operand_field.name[0] != '_') {
                        // try writer.print(
                        //     if (idx+1 == operand_fields.len)
                        //         " .{s} = {}"
                        //     else 
                        //         " .{s} = {},", // not correct if the last field is ~_~ (per if)
                        //     .{name_operand_field, @field(f, name_operand_field)}
                        // );
                        
                        try writer.print(
                            if (idx+1 == operand_fields.len)
                                " {}"
                            else 
                                " {},", // not correct if the last field is ~_~ (per if)
                            .{ @field(@field(value.operand, name), operand_field.name) }
                        );
                    }
                }
                
                try writer.print(" }}", .{});
                
                return;
            }
        }

        // categories.noop
        @panic("Unknown instruction"); // todo: change?
    }

    // todo: ~VariableLengthOperand~ still needs to be checked.
    /// v32:x8-l24
    pub const VariableLengthOperand = packed struct {
        /// x8-l24
        pub const Word = packed struct { _x: u8, a: i24 };  // this could probably just be a i24
 
        trailing: u32,
        additional: void,
        
        /// Length of additional words in bytes
        pub fn lenBytes(self: *align(1) const @This()) usize { return self.trailing * @sizeOf(Word); }
        pub fn words(self: *align(1) const @This()) []align(1) const Word {
            return @as([*]align(1) const Word, @ptrCast(&self.additional))[0..self.trailing];
        }

        pub fn format(value: VariableLengthOperand, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            const wds = value.words();
            
            try writer.writeAll("[");
            for (wds, 1..) |w, i| {
                try writer.print("{d}", .{w.a});
                if (i != wds.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeAll("]");
        }
    };

    pub const Directive = if (bopts.has_bytecode_module) 
        @import("bytecode").Directive 
    else 
        enum(u8) {_};

    // note: only checked in little-endian
    pub const Operand = if (bopts.has_bytecode_module) 
        @import("bytecode").Operand(VariableLengthOperand)
    else 
        packed union {}; 
};

pub fn getIterator(bv: ByteVector) Iterator {
    return .{ 
        .bv = bv,
        .c = bv.contents(u8),
    };
}

const Iterator = struct {
    bv: ByteVector,
    c: [] const u8,
    end: bool = false,

    const Self = @This();

    pub fn next(self: *Self) ?*const align(1) Bytecode {
        if (!bopts.has_bytecode_module) return null;
        if (self.end) return null;

        const out: * const align(1) Bytecode = @ptrCast(self.c.ptr);
        const step = out.getWidth();
        
        if (self.c.len > step) {
            self.c = self.c[step..];
        } else {
            self.end = true;
        }
        
        return out;
    }

    // pub fn peek(self: *Self) ?*const align(1) Bytecode {
    // }

    // pub fn reset(self: *Self) void {   
    // }
};

pub fn dissasemble(p: Procedure) Iterator {
    return getIterator(getBytecodeOf(p));
}

const scm_disassemble_program = "(@ (system vm disassembler) disassemble-program)";
const scm_get_bytecode =
    \\ (use-modules
    \\  (system vm program)
    \\  (system vm debug)
    \\  (rnrs bytevectors))
    \\ 
    \\ (define (get-bytes prog)
    \\   (let* ((addr     (program-code foo))
    \\          (debug    (find-program-debug-info addr))  
    \\          ;; bv elf of the entire image
    \\          (img      (program-debug-info-image debug)) 
    \\          ;; multiples of 4 bytes
    \\          ;; (/ (+ (program-debug-info-offset pdi)
    \\          ;;       (debug-context-text-base (program-debug-info-context pdi)))
    \\          ;;    4)
    \\          (start    (program-debug-info-u32-offset debug))
    \\          (end      (program-debug-info-u32-offset-end debug))
    \\          (size     (- end start))
    \\          (bv-chunk (make-bytevector (* 4 size))))
    \\     (bytevector-copy! img (* 4 start) bv-chunk 0 (* 4 size))
    \\     bv-chunk))
    \\ get-bytes
;

const cache = struct { 
    var gdisassemble: ?Procedure = null;
    var ggetbytecode: ?Procedure = null;
};

pub fn dissasembleToPort(p: Procedure, port: ?Port) void { 
    if (cache.gdisassemble == null) {
        cache.gdisassemble = gzzg.eval(scm_disassemble_program, null).raiseZ(Procedure).?;
    }

    _ = cache.gdisassemble.?.call(.{p, if(port != null) port.?.lowerZ() else Any.UNDEFINED});
}

pub fn getBytecodeOf(p: Procedure) ByteVector {
    if (cache.ggetbytecode == null) {
        cache.ggetbytecode = gzzg.eval(scm_get_bytecode, null).raiseZ(Procedure).?;
    }
    
    return cache.ggetbytecode.?.call(.{ p }).raiseZ(ByteVector).?;
}

// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("../gzzg.zig");
const bopts = @import("build_options");

const Any        = gzzg.Any;
const ByteVector = gzzg.ByteVector;
const Procedure  = gzzg.Procedure;
const Port       = gzzg.Port;

// todo: jtable fix
// note: types of ~v32:x8-l24~ eg. "jtable" are var-length. It is not currently correct
// and the lengths/sizes won't be calculated correctly. Nor will the following ops be correct.

pub const Bytecode = packed struct {
    directive: Directive,
    operand: Operand,

    /// gets the full op width (inc. directive)
    pub fn getWidth(op: *const align(1) @This()) usize {
        const Backing = @typeInfo(Bytecode.Directive).@"enum".tag_type;
        const max = std.math.maxInt(Backing);
        @setEvalBranchQuota(60_000);
        
        // there's probably a better way then also expanding no-op instructions > 166
        inline for(0..max) |dnum| {
            const d: Directive = @enumFromInt(dnum);
            
            if (op.directive == d) {
                if (comptime std.enums.tagName(Directive, d)) |name| {
                    const idx = std.meta.fieldIndex(Operand, name).?;
                    const bits = @bitSizeOf(std.meta.fields(Operand)[idx].type);
                    
                    return @divExact(bits, 8) + 1;
                } else {
                    @panic("Unknown instruction"); // <-----
                }
            }
        }
        
        unreachable;
    }

    pub fn format(value: Bytecode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        const Backing = @typeInfo(Directive).@"enum".tag_type;
        const max = std.math.maxInt(Backing);
        
        // you can't ~switch { inline else ... }~ over a non-exhaustive enum
        inline for(0..max) |dnum| {
            const d: Bytecode.Directive = @enumFromInt(dnum);
            
            if (value.directive == d) {
                if (comptime std.enums.tagName(Bytecode.Directive, d)) |name_directive| {
                    const f = @field(value.operand, name_directive);
                    const operand_fields = comptime std.meta.fieldNames(@TypeOf(f));
                    
                    try writer.print("{s}{{", .{ name_directive });
                    
                    inline for (operand_fields, 0..) |name_operand_field, idx| {
                        if (name_operand_field[0] != '_') {
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
                                .{@field(f, name_operand_field)}
                            );
                        }
                    }
                    
                    try writer.print(" }}", .{});
                    
                    return;
                } else {
                    @panic("Unknown instruction");
                }
            }
        }
        
        unreachable;
    }

    pub const Directive = if (bopts.has_bytecode_module) 
        @import("bytecode").Directive 
    else 
        enum(u8) {_};

    // note: only checked in little-endian
    pub const Operand = if (bopts.has_bytecode_module) 
        @import("bytecode").Operand
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

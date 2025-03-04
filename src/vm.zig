// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg.zig");
const guile = gzzg.guile;

const Any = gzzg.Any;
const Boolean = gzzg.Boolean;
const Number = gzzg.Number;
const Symbol = gzzg.Symbol;

//                                         ---------------
//                                         Stack §6.26.1.2
//                                         ---------------

// stacks are a struct/vtable
pub const Stack = struct {
    s: guile.SCM,

    // zig fmt: off
    // todo: check args required for make-stack
    pub fn make() Stack { return .{ .s = guile.scm_make_stack(Boolean.TRUE.s, guile.SCM_EOL) }; }

    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_stack_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }

    pub fn lowerZ(a: Stack) Any { return .{ .s = a.s }; }

    pub fn id(a: Stack) Any { return .{ .s = guile.scm_stack_id(a.s) }; }
    pub fn len(a: Stack) Number { return .{ .s = guile.scm_stack_length(a.s) }; }
    pub fn refE(a: Stack, idx: Number) Frame { return .{ .s = guile.scm_stack_ref(a.s, idx.s) }; }

    pub fn iterator(a: Stack) ConstStackIterator {
        const head = a.refE(Number.from(0));
        return .{
            .head = head,
            .frame = head,
        };
    }
    // display-backtrace
    
    // zig fmt: on
};

const ConstStackIterator = struct {
    head: Frame,
    frame: ?Frame,

    const Self = @This();

    // This next is identical to how stack-ref will grab a frame at an index (by calling previous multiple times)
    pub fn next(self: *Self) ?Frame {
        if (self.frame) |frm| {
            defer self.frame = frm.previous();
            return frm;
        } else {
            return null;
        }
    }

    pub fn peek(self: *Self) ?Frame {
        if (self.frame) |frm| {
            return frm.previous();
        } else {
            return null;
        }
    }

    pub fn reset(self: *Self) void {
        self.frame = self.head;
    }
};

//                                        ---------------
//                                        Frame §6.26.1.3
//                                        ---------------

pub const Frame = struct {
    s: guile.SCM,

    // zig fmt: off
    pub fn is (a: guile.SCM) Boolean { return .{ .s = guile.scm_frame_p(a) }; }
    pub fn isZ(a: guile.SCM) bool    { return is(a).toZ(); }

    pub fn lowerZ(a: Stack) Any { return .{ .s = a.s }; }

    pub fn previous(a: Frame) ?Frame {
        const prev = guile.scm_frame_previous(a.s);

        return if (Boolean.isZ(prev)) null else .{ .s = prev };
    }

    pub fn procedureName(a: Frame) ?Symbol {
        const frame = guile.scm_frame_procedure_name(a.s);

        return if (Boolean.isZ(frame)) null else .{ .s = frame };
    }
    
    // frame-arguments
    
    // frame-mv-return-address

    // frame-bindings
    // frame-lookup-bindings
    // bindings-index
    // bindings-name
    // bindings-slot
    // binding-representation

    // binding-ref
    // binding-set!
    // display-application
    
    // Note: The following procedures are based on the .h file, not the info doc

    pub fn address(a: Frame)            Number { return .{ .s = guile.scm_frame_address(a.s) }; }
    pub fn stackPointer(a: Frame)       Number { return .{ .s = guile.scm_frame_stack_pointer(a.s) }; }
    pub fn instructionPointer(a: Frame) Number { return .{ .s = guile.scm_frame_instruction_pointer(a.s) }; }

    // todo: check the following return types
    pub fn returnAddress(a: Frame) Any { return .{ .s = guile.scm_frame_return_address(a.s) }; }
    pub fn dynamicLink(a: Frame)   Any { return .{ .s = guile.scm_frame_dynamic_link(a.s) }; }
    pub fn callRepresentation(a: Frame) Any { return .{ .s = guile.scm_frame_call_representation(a.s) }; }
    pub fn arguments(a: Frame)     Any { return .{ .s = guile.scm_frame_arguments(a.s) }; }
    pub fn source(a: Frame)        Any { return .{ .s = guile.scm_frame_source(a.s) }; }    
};

pub const VMFrame = struct {
    
};

pub const EngineEnum = enum(u4) {
    regular = guile.SCM_VM_REGULAR_ENGINE,
    debug = guile.SCM_VM_DEBUG_ENGINE,

    pub fn asSymbol(a: EngineEnum) Symbol {
        const container = struct {
            var symRegular: ?Symbol = null;
            var symDebug: ?Symbol = null;
        };

        switch (a) {
            .regular => {
                if (container.symRegular == null) {
                    container.symRegular = Symbol.from("regular");
                }

                return container.symRegular.?;
            },
            .debug => {
                if (container.symDebug == null) {
                    container.symDebug = Symbol.from("debug");
                }

                return container.symDebug.?;
            }
        }
    }

    pub fn fromSymbol(a: Symbol) ?EngineEnum {
        if (gzzg.eq(a, EngineEnum.regular.asSymbol())) {
            return .regular;
        } else if (gzzg.eq(a, EngineEnum.debug.asSymbol())) {
            return .debug;
        }

        return null;
    }

    comptime {
        std.debug.assert(guile.SCM_VM_NUM_ENGINES == @typeInfo(@This()).Enum.fields.len);
    }
};


pub const VM = struct {
    // libguile/vm.h

    // SCM_API SCM scm_call_with_vm (SCM proc, SCM args);
    // SCM_API SCM scm_call_with_stack_overflow_handler (SCM limit, SCM thunk,
    //                                                   SCM handler);
    
    pub fn traceLevel() Number { return .{ .s = guile.scm_vm_trace_level() }; }
    pub fn traceLevelX(a: Number) void { return .{ .s = guile.scm_set_vm_trace_level_x(a.s) }; }
    pub fn engine() EngineEnum {
        // shouldn't fail with null
        return EngineEnum.fromSymbol(.{ .s = guile.scm_vm_engine() }).?;
    }

    pub fn engineX(a: EngineEnum) void { _ = guile.scm_set_vm_engine_x(a.asSymbol().s); }
    // SCM_API SCM scm_set_default_vm_engine_x (SCM engine);
    pub fn engineXZ(a: EngineEnum) void { guile.scm_c_set_vm_engine_x(@intFromEnum(a)); }
    // SCM_API void scm_c_set_default_vm_engine_x (int engine);

    pub fn loadCompiledWithVM(file: Any) Any { return .{ .s = guile.scm_load_compiled_with_vm(file.s) }; }

    // #define SCM_VM_CONT_P(OBJ)      
    // #define SCM_VM_CONT_DATA(CONT)  
    // #define SCM_VM_CONT_PARTIAL_P(CONT) 
    // #define SCM_VM_CONT_REWINDABLE_P(CONT)

    // Red flags!
    pub fn currentThreadVM() *guile.scm_vm {
        return &gzzg.Thread.current().data().vm;
    }
};


//SCM_FRAME_PREVIOUS_SP(fp)

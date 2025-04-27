// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std   = @import("std");
const gzzg  = @import("gzzg.zig");
const guile = gzzg.guile;

const Symbol = gzzg.Symbol;

//                                      ---------------------
//                                      Foreign Objects §6.20
//                                      ---------------------

pub const Identity = struct {
    s: guile.SCM,

    pub const guile_name = "foreign-type";

    comptime {
        _ = gzzg.contracts.GZZGType(@This(), void);
    }
};

// pub fn makeForeignObjectType1(name: Symbol, slot: Symbol) ForeignType {
//     return .{ .s = guile.scm_make_foreign_object_type(name.s, guile.scm_list_1(slot.s), null) };
// }

//todo add checks
//todo: Foreign Objects are based on Goops (vtables). Consider method implementations?
//      See also src libguile/foreign-object.c
//      Consider look at guile structures since vtables are build on that too.
// pub fn SetupFT(comptime ft: type, comptime cct: type, name: [:0]const u8, slot: [:0]const u8) type {
//     return struct {
//         var scmType: ForeignType = undefined;
//         const CType: type = cct;

//         pub fn assert(a: guile.SCM) void {
//             guile.scm_assert_foreign_object_type(scmType.s, a);
//             // ---------------------- libguile/foreign-object.c:72
//             // void
//             // scm_assert_foreign_object_type (SCM type, SCM val)
//             // {
//             //   /* FIXME: Add fast path for when type == struct vtable */
//             //   if (!SCM_IS_A_P (val, type))
//             //     scm_error (scm_arg_type_key, NULL, "Wrong type (expecting ~A): ~S",
//             //                scm_list_2 (scm_class_name (type), val), scm_list_1 (val));
//             // }
//         }

//         pub fn registerType() void {
//             scmType = makeForeignObjectType1(Symbol.from(name), Symbol.from(slot));
//         }

//         pub fn makeSCM(data: *cct) ft {
//             return .{ .s = guile.scm_make_foreign_object_1(scmType.s, data) };
//         }

//         // const mak = if (@sizeOf(cct) <= @sizeOf(*anyopaque)) i32 else i16;
//         // todo: It's possible to store small data inside the pointer rather then alloc
//         pub fn retrieve(a: ft) ?*cct {
//             const p = guile.scm_foreign_object_ref(a.s, 0);

//             return if (p == null) null else @alignCast(@ptrCast(p.?));
//         }

//         pub fn make(alloct: std.mem.Allocator) !*cct {
//             return alloct.create(CType);
//         }
//     };
// }

const Any     = gzzg.Any;
const Boolean = gzzg.Boolean;
const ListOf  = gzzg.ListOf;

fn SlotsToEnum(comptime declared_slots: anytype) type {
    var fields:[declared_slots.len]std.builtin.Type.EnumField = undefined;

    for (declared_slots, 0..) |slot, i| {
        fields[i] = .{
            .name = @tagName(slot),
            .value = i,
        };
    }
    
    return @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, declared_slots.len - 1),
            .fields = &fields,
            .decls = &.{},
            .is_exhaustive = true,            
        },
    });
}

pub fn ForeignObjectOf(
    comptime T: type,
    comptime name: []const u8,
    comptime declared_slots: anytype,
    comptime finaliser: anytype) // * fn (ForeignObjectOf(T)) void. Recursive type workaround.
    type
{
    // todo check that all slots are pointers or scm objects or smaller than or equal to the pointer size.
    // todo check if object is smaller than a pointer and consider storing in the pointer bits.
    // actually rather than SCM types only. Only objects with a single member that's a pointer should be allowed
    // otherwise pointer only.
        
    for (declared_slots) |slot_tag| {
        const slot = @tagName(slot_tag);
        if (!@hasField(T, slot)) @compileError("Slot '"++slot++"' missing from T: " ++ @typeName(T));
        
        const Slot = @FieldType(T, slot);

        switch (@typeInfo(Slot)) {
            .@"struct" => |st| {
                
                if (st.fields.len != 1)
                    @compileError("On '"++slot++"', unsuported type: " ++ @typeName(Slot) ++ " due to multiple members");

                switch (@typeInfo(st.fields[0].type)) {
                    .pointer => {},
                    .optional => |o| {
                        if (std.meta.activeTag(@typeInfo(o.child)) != .pointer) {
                            @compileError("On '"++slot++"', unsuported type: " ++ @typeName(Slot) + " not a pointer");
                        }
                    },
                    else => @compileError("On '"++slot++"', unsuported type: " ++ @typeName(Slot)),
                }
                
            },
            .@"pointer" => {},
            else => @compileError("Unsupported type on slot '"++slot++"' for T: " ++ @typeName(T)),
        }
    }

    const hasFinaliser = 
        check: switch (@typeInfo(@TypeOf(finaliser))) {
            .@"fn" => |f| init: {
                if (f.return_type.? != void) @compileError("Finaliser must return 'void'");
                if (f.params.len != 1) @compileError("Finaliser must have only one param");
                
                break :init true;
            },
            .pointer => |p| {
                if (p.size != .one) @compileError("Bad pointer");
                
                continue :check @typeInfo(p.child);
            },
            .null => false,
            else => @compileError("Bad finaliser value")
    };

    const SlotEnum = SlotsToEnum(declared_slots);

    return extern struct {
        pub var slots: [declared_slots.len] Symbol = undefined;
        pub var foreign: Identity = undefined;
        s: guile.SCM,

        pub const guile_name = "foreign-type:" ++ name; //maybe?
        
        pub fn is (a: guile.SCM) Boolean {
            _ = a;
            return Boolean.verum;
            //@panic("Unimplemented");
        }
        pub fn isZ(a: guile.SCM) bool { return is(a).toZ(); }

        pub fn lowerZ(a: @This()) Any { return .{ .s = a.s }; }
        
        pub fn registerType() void {
            inline for (declared_slots, 0..) |slot_tag, idx| 
                slots[idx] = .fromUTF8(@tagName(slot_tag));
            
            const ft = guile.scm_make_foreign_object_type(
                Symbol.fromUTF8(name).s,
                ListOf(Symbol).init(slots).s,
                if (hasFinaliser) wrappedFinaliser else null
            );

            foreign = .{ .s = ft };
        }

        fn wrappedFinaliser(a: guile.SCM) callconv(.c) void {
            @call(.auto, finaliser, .{ @This(){ .s = a } });
        }

        inline fn getObjectPointer(value: anytype) *anyopaque {
            const field = std.meta.fields(@TypeOf(value))[0];
            
            return @constCast(@alignCast(@ptrCast(@field(value, field.name))));
        }
        
        inline fn getObject(ptr: *anyopaque, comptime Q: type) Q {
            const field = std.meta.fields(Q)[0];
            var obj:Q = undefined;
            
            @field(obj, field.name) = @ptrCast(ptr);
            
            return obj;
        }

        pub fn make(obj: T) @This() {
            var objSlots:[declared_slots.len] *anyopaque = undefined;
            
            inline for (declared_slots, 0..) |slot_tag, idx| {
                const slot = @tagName(slot_tag);
                const Slot = @FieldType(T, slot);

                objSlots[idx] = switch (@typeInfo(Slot)) {
                    .@"struct" => getObjectPointer(@field(obj, slot)),
                    .pointer => @ptrCast(@field(obj, slot)),
                    else => unreachable,
                };
            }
            
            return .{ .s = guile.scm_make_foreign_object_n(foreign.s, objSlots.len, @ptrCast(&objSlots)) }; 
        }

        pub fn assemble(a: @This()) T {
            var t:T = undefined;

            inline for (declared_slots, 0..) |slot_tag, idx| {
                const slot = @tagName(slot_tag);
                const Slot = @FieldType(T, slot);
                const ref = guile.scm_foreign_object_ref(a.s, idx);
                
                @field(t, slot) =
                    switch (@typeInfo(Slot)) {
                        .@"struct" => getObject(ref.?, Slot),
                        .pointer => @alignCast(@ptrCast(ref)),
                        else => unreachable,
                };
            }

            return t;
        }

        pub fn SlotType(comptime tag: SlotEnum) type {
            return @FieldType(T, @tagName(tag));
        }

        pub fn SlotIdx(comptime tag: SlotEnum) comptime_int {
            for (declared_slots, 0..) |slot_tag, i| {
                if (slot_tag == tag) return i;
            }

            @compileError("Bad tag");
        }

        pub fn getSlot(a: @This(), comptime tag: SlotEnum) SlotType(tag) {
            const Slot = SlotType(tag);
            const raw_slot = guile.scm_foreign_object_ref(a.s, SlotIdx(tag));

            return switch (@typeInfo(Slot)) {
                .@"struct" => getObject(raw_slot.?, Slot),                        
                .pointer => @alignCast(@ptrCast(raw_slot)),
                else => unreachable,
            };
        }

        pub fn setSlot(a: @This(), comptime tag: SlotEnum, value: SlotType(tag)) void  {
            const Slot = SlotType(tag);
            const raw_slot = switch (@typeInfo(Slot)) {
                .@"struct" => getObjectPointer(value),
                .pointer => value,
                else => unreachable
            };

            guile.scm_foreign_object_set_x(a.s, SlotIdx(tag), @ptrCast(raw_slot));
        }

        comptime {
            _ = gzzg.contracts.GZZGType(@This(), void);
        }        
    };
}

// const Test = struct {
//     const slots = .{ "bv", "img", "sym"};
//     const Foreign = ForeignObjectOf(@This(), "zbar-image", &slots, null);
    
//     bv: gzzg.Bytevector,
//     img: std.fs.File,
//     sym: std.Uri,

//     pub fn register() void {
//         Foreign.registerType();
//         _ =  gzzg.Procedure.define("do-action", Foreign.bind(doAction), null, true);
//         _ =  gzzg.Procedure.define("do-action2", bindDoAction, null, true);
//     }

//     fn bindDoAction(self: Foreign) void {
//         self.assemble().doAction();
//     }
    
//     fn doAction(self: @This()) void {
//         _ = self.sym.fragment;
//     }

//     comptime {
//         Foreign.checkBind(bindDoAction, doAction); 
//     }
// };

// const MakeOutline(ff: anytype) Outline {
// }

// const Outline = struct {
//     fnp: *anyopaque,
//     required: usize,
//     optional: usize,
//     rest: bool,
// };

// fn defineFn() void {
// }

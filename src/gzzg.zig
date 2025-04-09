// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

pub const guile = @import("guile");

pub const GuileGCAllocator = @import("Allocator.zig");

/// Zig implementation of Guiles bit stuffing rules. libguile/scm.h
pub const internal_workings = @import("internal_workings.zig");
pub const contracts         = @import("contracts.zig");

pub const Any = @import("any.zig").Any;

// §6.6 Data Types
pub const Boolean    = @import("boolean.zig").Boolean;
pub const Number     = @import("number.zig").Number;
pub const Integer    = @import("number.zig").Integer;
pub const Character  = @import("string.zig").Character;
// Character Sets
pub const String     = @import("string.zig").String;
pub const Symbol     = @import("string.zig").Symbol;
pub const Keyword    = @import("string.zig").Keyword;
pub const Pair       = @import("list.zig").Pair;
pub const ListOf     = @import("list.zig").ListOf;
pub const List       = ListOf(Any);
pub const VectorOf   = @import("vector.zig").VectorOf;
pub const Vector     = VectorOf(Any);
// Bit Vectors
pub const ByteVector = @import("byte_vector.zig").ByteVector;
//Arrays
//VLists
//Records
//Structures
//Association Lists
//VHashs
//pub const HashTable = SCMWrapper(null);

//

pub const Port      = @import("port.zig").Port;
pub const ZigIO     = @import("zig_port.zig").ZigIO;
pub const WrapZigIO = @import("zig_port.zig").WrapZigIO;

//
// Not ready for use.
const Smob   = @import("smob.zig").Smob;
const Thread = @import("thread.zig").Thread;
const Hook   = @import("hook.zig").Hook;

//

pub const Module      = @import("program.zig").Module;
pub const Procedure   = @import("program.zig").Procedure;
pub const ThunkOf     = @import("program.zig").ThunkOf;
pub const Thunk       = ThunkOf(Any);
pub const ForeignType = @import("foreign_object.zig").ForeignType;

//

// Not ready for use
const Stack = @import("vm.zig").Stack;
const Frame = @import("vm.zig").Frame;


//                                       ------------------
//                                       Bit Vector §6.6.11
//                                       ------------------

//                                         --------------
//                                         Arrays §6.6.13
//                                         --------------

//                                          -------------
//                                          VList §6.6.14
//                                          -------------

//                                --------------------------------
//                                Record §6.6.15, §6.6.16, §6.6.17
//                                --------------------------------

//                                        -----------------
//                                        Structure §6.6.18
//                                        -----------------

//                                          -------------
//                                          VHash §6.6.21
//                                          -------------

//================================================+==================================================
//                                        -----------------
//                                        HashTable §6.6.22
//                                        -----------------

pub const initThreadForGuile = guile.scm_init_guile;

const core = @import("core.zig");
pub const MultiValue              = core.MultiValue;
pub const StaticCache             = core.StaticCache;
pub const UnionSCM                = core.UnionSCM;
pub const catchException          = core.catchException;
pub const catchExceptionC         = core.catchExceptionC;
pub const display                 = core.display;
pub const displayErr              = core.displayErr;
pub const eval                    = core.eval;
pub const newline                 = core.newline;
pub const newlineErr              = core.newlineErr;
pub const orUndefined             = core.orUndefined;
pub const withContinuationBarrier = core.withContinuationBarrier;

pub const eq                      = core.eq;
pub const eqv                     = core.eqv;
pub const equal                   = core.equal;
pub const eqZ                     = core.eqZ;

pub const fmt = @import("fmt.zig");

test {
    @import("std").testing.refAllDecls(@This());
}

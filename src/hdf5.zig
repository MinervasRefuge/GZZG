// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const g = gzzg;

const guile = gzzg.guile;

// zig fmt: off
pub const h5 = @cImport({
    // @cInclude("H5Apublic.h");   // Attributes (H5A)
    @cInclude("H5Dpublic.h");   // Datasets (H5D)
    @cInclude("H5Spublic.h");   // Dataspaces (H5S)
    @cInclude("H5Tpublic.h");   // Datatypes (H5T)
    // @cInclude("H5Epublic.h");   // Error Handling (H5E)
    // @cInclude("H5ESpublic.h");  // Event Set (H5ES)
    @cInclude("H5Fpublic.h");   // Files (H5F)
    // @cInclude("H5Zpublic.h");   // Filters (H5Z)
    @cInclude("H5Gpublic.h");   // Groups (H5G)
    // @cInclude("H5Ipublic.h");   // Identifiers (H5I)
    @cInclude("H5public.h");    // Library General (H5)
    @cInclude("H5Lpublic.h");   // Links (H5L)
    // @cInclude("H5Opublic.h");   // Objects (H5O)
    @cInclude("H5Ppublic.h");   // Property Lists (H5P)
    // @cInclude("H5PLpublic.h");  // Dynamically-loaded Plugins (H5PL)
    // @cInclude("H5Rpublic.h");   // References (H5R)
    // @cInclude("H5VLpublic.h");  // VOL Connector (H5VL)
});
// zig fmt: on

var gc = g.GuileGCAllocator{ .what = "HDF5" };
var alloc = gc.allocator();

export fn initHDF5() void {
    _ = g.defineModule("hdf5", initHDF5Module);
}

//todo is H5HID a HNDL or just and ID?
fn initHDF5Module() void {
    // zig fmt: off
    _ = g.defineGSubRAndExportBulk(.{
        .{ .name = "open-h5",  .func = openH5,  .doc = "openH5(file: String, _: List) !H5HID" },
        .{ .name = "close-h5", .func = closeH5, .doc = "closeH5(hdl: H5HID) void"},
        
        .{ .name = "open-group",  .func = openH5Group,    .doc = "openH5Group(h5Hndl: H5HID, path: String) !H5HID"},
        .{ .name = "close-group", .func = closeH5Group,   .doc = "closeH5Group(h5GroupHndl: H5HID) void" },
            
        .{ .name = "group-links", .func = getGroupsLinks, .doc = "getGroupsLinks(group: H5HID) List"},
            
        .{ .name = "open-dataset",  .func = openH5Dataset,  .doc = "openH5Dataset(hndl: H5HID, path: String) !H5HID"},
        .{ .name = "close-dataset", .func = closeH5Dataset, .doc = "closeH5Dataset(hndl: H5HID) void"},
            
        .{ .name = "get-layout",   .func = getLayout,   .doc = "getLayout(plist_id: H5HID) Symbol"},
        .{ .name = "read-dataset", .func = readDataset, .doc = "readDataset(dataset_hndl: H5HID) void"},
    
        .{ .name = "get-dataset-dataspace", .func = getDatasetSpace, .doc = "getDatasetSpace(dataset_hndl: H5HID) !H5HID"},
        .{ .name = "close-dataspace",       .func = closeDataSpace,   .doc = "closeDataSpace(dataspace_hndl: H5HID) void"},
    
        .{ .name = "get-dataset-plist", .func = getDatasetPList, .doc = "getDatasetPList(dataset_hndl: H5HID) H5HID"},
        .{ .name = "close-plist",       .func = closePList,      .doc = "closePList(plist_hndl: H5HID) void"}, 
        .{ .name = "get-properties",    .func = getProperties,   .doc = "getProperties(plist_hndl: H5HID) List"},
    
        .{ .name = "get-type",       .func = getType,      .doc = "getType(dataset_hndl: H5HID) !H5HID"},
        .{ .name = "get-type-class", .func = getTypeClass, .doc = "getTypeClass(type_hndl: H5HID) Symbol"},
        .{ .name = "close-type",     .func = closeType,    .doc = "closeType(type_hndl: H5HID) void"},

        .{ .name = "i-get-type", .func = iGetType},
        .{ .name = "open-object", .func = openObject },
        .{ .name = "close-object", .func = closeObject},
    });
    // zig fmt: on

    H5HID.register();
    H5GInfo.register();

    H5LInfo2.register();
    H5OInfo2.register();
}

pub fn openH5(file: g.String, _: g.List) !H5HID {
    //    H5F_ACC_RDWR
    //        H5F_ACC_RDONLY

    const v = try file.toCStr(alloc);
    defer alloc.free(v);

    return switch (h5.H5Fopen(v, 0, h5.H5P_DEFAULT)) {
        h5.H5I_INVALID_HID => error.InvalidHID,
        else => |r| H5HID.init(r),
    };
}

pub fn closeH5(hdl: H5HID) void {
    _ = h5.H5Fclose(hdl.to());
}

pub fn openH5Group(h5Hndl: H5HID, path: g.String) !H5HID { //todo H5HID or #f
    const v = try path.toCStr(alloc);
    defer alloc.free(v);

    return H5HID.init(h5.H5Gopen1(h5Hndl.to(), v));
}

pub fn closeH5Group(h5GroupHndl: H5HID) void {
    _ = h5.H5Gclose(h5GroupHndl.to());
}

pub fn openH5Dataset(hndl: H5HID, path: g.String) !H5HID {
    return switch (h5.H5Dopen2(hndl.to(), try path.toCStr(alloc), h5.H5P_DEFAULT)) {
        h5.H5I_INVALID_HID => error.InvalidHID,
        else => |r| H5HID.init(r),
    };
}

pub fn closeH5Dataset(hndl: H5HID) void {
    _ = h5.H5Dclose(hndl.to());
}

//
//

const H5HID = struct {
    s: guile.SCM,

    pub fn register() void {
        @This().registerType();
    }

    pub fn init(h: h5.hid_t) H5HID {
        //   if (@typeInfo(h5.hid_t).Int.bits == @typeInfo(usize).Int.bits) { // can I stuff the bits into the pointer
        //       return @This().makeSCM(@ptrFromInt(@as(usize, @bitCast(h))));
        //   } else {
        const p = @This().make(alloc) catch @trap();
        p.* = h;

        return @This().makeSCM(p);
        //}
    }

    pub fn to(h: H5HID) h5.hid_t {
        H5HID.assert(h.s);

        //if (@typeInfo(h5.hid_t).Int.bits == @typeInfo(usize).Int.bits) {
        //    return @bitCast(@intFromPtr(guile.scm_foreign_object_ref(h.s, 0)));
        //} else {
        return @This().retrieve(h).?.*;
        //}
    }

    usingnamespace g.SetupFT(H5HID, h5.hid_t, "H5HID", "hndl");
};

const H5GInfo = struct {
    s: guile.SCM,

    pub fn register() void {
        @This().registerType();

        _ = g.defineGSubRAndExport("h5-group-info", get, "get(groupHndl: H5HID) H5GInfo");
        _ = g.defineGSubRAndExport("h5-group-info->string", toString, "toString(a: H5GInfo) String");
    }

    pub fn get(groupHndl: H5HID) H5GInfo {
        H5HID.assert(groupHndl.s);
        const gi = @This().make(alloc) catch @trap();

        _ = h5.H5Gget_info(groupHndl.to(), gi);

        return @This().makeSCM(gi);
    }

    pub fn toString(a: H5GInfo) g.String {
        @This().assert(a.s);

        const ci: *h5.H5G_info_t = @This().retrieve(a).?;

        // zig fmt: off
        const s = std.fmt.allocPrintZ(alloc, "storage: {} nlinks: {d} max_corder: {d} mounted: {}",
                                      .{ci.storage_type, ci.nlinks, ci.max_corder, ci.mounted})
            catch @trap();

        defer alloc.free(s);
        
        // zig fmt: on
        return g.String.from(s);
    }

    usingnamespace g.SetupFT(H5GInfo, h5.H5G_info_t, "H5GInfo", "info");
};

//const sas: h5.H5L_iterate2_t = undefined;
// pub const H5L_iterate2_t = (group:h5.hid_t, name: [*c]const u8, info: [*c]const h5.H5L_info2_t, op_data:?*anyopaque) callconv(.C) h5.herr_t

const H5LInfo2 = struct {
    s: guile.SCM,

    pub fn register() void {
        @This().registerType();

        _ = g.defineGSubRAndExport("link-info2->string", toString, "toString(a: H5LInfo2) String");
    }

    pub fn init(ic: *const h5.H5L_info2_t) H5LInfo2 {
        const info = @This().make(alloc) catch @trap();
        const sz = @sizeOf(h5.H5L_info2_t);

        @memcpy(@as(*[sz]u8, @ptrCast(info)), std.mem.asBytes(ic)[0..sz]);

        return @This().makeSCM(info);
    }

    pub fn toString(a: H5LInfo2) g.String {
        const i: *h5.H5L_info2_t = @This().retrieve(a).?;

        //const s = std.json.stringifyAlloc(alloc, i, .{}) catch @trap();

        const us = if (i.cset == 0) std.fmt.allocPrint(alloc, "{}", .{i.u.token}) else std.fmt.allocPrint(alloc, "{}", .{i.u.val_size});

        const s = std.fmt.allocPrint(alloc, "type: {} corder_valid:{} corder:{} cset:{}, u: {s}", .{ i.type, i.corder_valid, i.corder, i.cset, us catch @trap() }) catch @trap();

        defer alloc.free(s);

        return g.String.from(s);
    }

    usingnamespace g.SetupFT(H5LInfo2, h5.H5L_info2_t, "H5LInfo2", "info");
};

fn linkIter(group: h5.hid_t, name: [*c]const u8, info: [*c]const h5.H5L_info2_t, op_data: ?*anyopaque) callconv(.C) h5.herr_t {
    _ = group;

    var l: *g.List = @alignCast(@ptrCast(op_data));

    l.* = l.cons(g.Pair.from(g.String.from(std.mem.span(name)), H5LInfo2.init(info)));

    return 0;
}

//todo rename
pub fn getGroupsLinks(group: H5HID) g.List {
    var l: g.List = g.List.init(.{});

    _ = h5.H5Lvisit2(group.to(), h5.H5_INDEX_NAME, h5.H5_ITER_NATIVE, linkIter, @ptrCast(&l));

    return l;
}

pub fn getLayout(plist_id: H5HID) g.Symbol {
    return g.Symbol.fromEnum(@as(H5DLayout, @enumFromInt(h5.H5Pget_layout(plist_id.to()))));
}

// zig fmt: off
const H5DLayout = RecreateEnum(h5.enum_H5D_layout_t, h5, .{
    "H5D_LAYOUT_ERROR",
    "H5D_COMPACT",
    "H5D_CONTIGUOUS",
    "H5D_CHUNKED",
    "H5D_VIRTUAL",
    "H5D_NLAYOUTS"
});
// zig fmt: off

//pub fn getDataSpace(dataset_hndl: H5HID)

pub fn readDataset(dataset_hndl: H5HID) void {
    const dhndl = dataset_hndl.to();
    const size = h5.H5Dget_storage_size(dhndl);

    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocstd = gpa.allocator();

    const buf = alloc.alloc(u8, size) catch @trap();
    std.debug.print("buffer size:{d}\n", .{buf.len});

    _ = h5.H5Dread(dhndl, h5.H5T_NATIVE_INT_g, h5.H5S_ALL, h5.H5S_ALL, h5.H5P_DEFAULT, buf.ptr);
    //allocstd.free(buf);
}

pub fn getDatasetSpace(dataset_hndl: H5HID) !H5HID {
    return switch (h5.H5Dget_space(dataset_hndl.to())) {
        h5.H5I_INVALID_HID => error.InvalidHID,
        else => |r| H5HID.init(r)
    };
}

pub fn closeDataSpace(dataspace_hndl: H5HID) void {
    _ = h5.H5Sclose(dataspace_hndl.to());
}

pub fn getDatasetPList(dataset_hndl: H5HID) H5HID {
    return H5HID.init(h5.H5Dget_create_plist(dataset_hndl.to()));
}

pub fn closePList(plist_hndl: H5HID) void {
    _ = h5.H5Pclose(plist_hndl.to());
}

pub fn getProperties(plist_hndl: H5HID) g.List {
    var l = g.List.init(.{});

    _ = h5.H5Piterate(plist_hndl.to(), null, propIter, @ptrCast(&l));

    return l;
}

//h5.H5P_iterate_t

//?*const fn (hid_t, [*c]const u8, ?*anyopaque) callconv(.C) herr_t;

//hid_t id, const char *name, void *iter_data)
//fn propIter(id: h5.hid_t, name: [*c]const u8, iter_data: ?*anyopaque) callconv(.C) h5.herr_t {
fn propIter(_: h5.hid_t, name: [*c]const u8, iter_data: ?*anyopaque) callconv(.C) h5.herr_t {
    var l: *g.List = @alignCast(@ptrCast(iter_data));

    l.* = l.cons(g.String.from(std.mem.span(name)));

    return 0;
}

fn getType(dataset_hndl: H5HID) !H5HID {
    return switch (h5.H5Dget_type(dataset_hndl.to())) {
        h5.H5I_INVALID_HID => error.InvalidHID,
        else => |r| H5HID.init(r)
    };
}

// zig fmt: off
fn getTypeClass(type_hndl: H5HID) g.Symbol {
    return g.Symbol.fromEnum(@as(H5TTypes, @enumFromInt(h5.H5Tget_class(type_hndl.to()))));
}
// zig fmt: on

fn closeType(type_hndl: H5HID) void {
    _ = h5.H5Tclose(type_hndl.to());
}
//
////H5Tget_class => H%T_COMPOUND

// zig fmt: off
const H5TTypes = RecreateEnum(h5.enum_H5T_class_t, h5, .{
    "H5T_NO_CLASS",
    "H5T_INTEGER",
    "H5T_FLOAT",
    "H5T_TIME",
    "H5T_STRING",
    "H5T_BITFIELD",
    "H5T_OPAQUE",
    "H5T_COMPOUND",
    "H5T_REFERENCE",
    "H5T_ENUM",
    "H5T_VLEN",
    "H5T_ARRAY",
    "H5T_NCLASSES"
});

// zig fmt: on

pub fn RecreateEnum(tag_type: type, from: anytype, parms: anytype) type {
    // zig fmt: off
    const EnumField = std.builtin.Type.EnumField;
    
    comptime var fields: [parms.len]EnumField = undefined;
    
    // for a tag "H5T_NCLASSES" we want to chop off "H5T_" (since it's just a /c namespace/) and keep the rest.
    inline for (0..parms.len) |i| {
        var it = std.mem.tokenizeAny(u8, parms[i], "_");

        _ = it.next();
        
        fields[i] = EnumField{
            .name = std.fmt.comptimePrint("{s}", .{it.rest()}),
            .value = @field(from, parms[i])
        };
    }
    
    return @Type(.{
        .Enum = .{
            .tag_type = tag_type,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true
        }
    });
    // zig fmt: on
}

// zig fmt: off
const H5OType = RecreateEnum(h5.enum_H5O_type_t, h5, .{
    "H5O_TYPE_UNKNOWN",
    "H5O_TYPE_GROUP",
    "H5O_TYPE_DATASET",
    "H5O_TYPE_NAMED_DATATYPE",
    "H5O_TYPE_MAP",
    "H5O_TYPE_NTYPES"
});
// zig fmt: on

const H5OInfo2 = struct {
    s: guile.SCM,

    pub fn register() void {
        @This().registerType();

        _ = g.defineGSubRAndExport("object-info2->string", toString, "toString(a: H5OInfo2) String");
        _ = g.defineGSubRAndExport("object-info2->otype", getOType, "getOType(a: H5OInfo2) Symbol");
        _ = g.defineGSubRAndExport("make-object-info2", getH5OInfo2, "getH5OInfo2(loc_id: H5HID) H5OInfo2");
    }

    pub fn init(ic: *const h5.H5O_info2_t) H5OInfo2 {
        const info = @This().make(alloc) catch @trap();
        const sz = @sizeOf(h5.H5O_info2_t);

        @memcpy(@as(*[sz]u8, @ptrCast(info)), std.mem.asBytes(ic)[0..sz]);

        return @This().makeSCM(info);
    }

    pub fn toString(_: H5OInfo2) g.String {
        //     const i: *h5.H5O_info2_t = @This().retrieve(a).?;

        //const s = std.json.stringifyAlloc(alloc, i, .{}) catch @trap();

        return g.String.from("FIX ME");
    }

    pub fn getOType(a: H5OInfo2) g.Symbol {
        const b = @This().retrieve(a).?;

        return g.Symbol.fromEnum(@as(H5OType, @enumFromInt(b.type)));
    }

    fn getH5OInfo2(loc_id: H5HID) H5OInfo2 {
        var data: h5.H5O_info2_t = .{};

        // todo: deal with return data
        _ = h5.H5Oget_info3(loc_id.to(), &data, h5.H5O_INFO_ALL);

        // todo: Double handling data using the constructor. Better would be init empty then refer to contents.

        return init(&data);
    }

    usingnamespace g.SetupFT(H5OInfo2, h5.H5O_info2_t, "H5OInfo2", "info");
};

// zig fmt: off
fn iGetType(id: H5HID) g.Symbol {
    const b = h5.H5Iget_type(id.to());
    
    return g.Symbol.fromEnum(@as(H5IType, @enumFromInt(b)));
}

const H5IType = RecreateEnum(h5.enum_H5I_type_t, h5, .{
    "H5I_UNINIT",
    "H5I_BADID",
    "H5I_FILE",
    "H5I_GROUP",
    "H5I_DATATYPE",
    "H5I_DATASPACE",
    "H5I_DATASET",
    "H5I_MAP",
    "H5I_ATTR",
    "H5I_VFL",
    "H5I_VOL",
    "H5I_GENPROP_CLS",
    "H5I_GENPROP_LST",
    "H5I_ERROR_CLASS",
    "H5I_ERROR_MSG",
    "H5I_ERROR_STACK",
    "H5I_SPACE_SEL_ITER",
    "H5I_EVENTSET",
    "H5I_NTYPES"
});

fn openObject(hndl: H5HID, path: g.String) !H5HID {
    return switch (h5.H5Oopen(hndl.to(), try path.toCStr(alloc), h5.H5P_DEFAULT)) {
        h5.H5I_INVALID_HID => error.InvalidHID,
        else => |r| H5HID.init(r),
    };
}

pub fn closeObject(hndl: H5HID) void {
    _ = h5.H5Oclose(hndl.to());
}

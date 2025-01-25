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

var gc = g.GuileGCAllocator{};
var alloc = gc.allocator();

export fn init_hdf5() void {
    _ = g.defineModule("hdf5", init_hdf5_module);
}

//todo is H5HID a HNDL or just and ID?
fn init_hdf5_module() void {
    _ = g.defineGSubRAndExport("open-h5", openH5);
    _ = g.defineGSubRAndExport("close-h5", closeH5);

    _ = g.defineGSubRAndExport("open-group", openH5Group);
    _ = g.defineGSubRAndExport("close-group", closeH5Group);

    _ = g.defineGSubRAndExport("group-links", getGroupsLinks);

    _ = g.defineGSubRAndExport("open-dataset", openH5Dataset);
    _ = g.defineGSubRAndExport("close-dataset", closeH5Dataset);

    _ = g.defineGSubRAndExport("get-layout", getLayout);
    _ = g.defineGSubRAndExport("read-dataset", readDataset);

    _ = g.defineGSubRAndExport("get-dataset-dataspace", getDatasetSpace);
    _ = g.defineGSubRAndExport("close-dataspace", closeDataSpace);

    _ = g.defineGSubRAndExport("get-dataset-plist", getDatasetPList);
    _ = g.defineGSubRAndExport("close-plist", closePList);
    _ = g.defineGSubRAndExport("get-properties", getProperties);

    _ = g.defineGSubRAndExport("get-type", getType);
    _ = g.defineGSubRAndExport("get-type-class", getTypeClass);

    H5HID.register();
    H5GInfo.register();

    H5LInfo2.register();

    // Datatypes (H5T)
    _ = g.defineGSubRAndExport("close-type", closeType);
}

pub fn openH5(file: g.String, _: g.List) H5HID {
    //    H5F_ACC_RDWR
    //        H5F_ACC_RDONLY

    const v = file.toCStr(alloc) catch @trap();
    defer alloc.free(v);
    return H5HID.init(h5.H5Fopen(v, 0, h5.H5P_DEFAULT));
}

pub fn closeH5(hdl: H5HID) void {
    _ = h5.H5Fclose(hdl.to());
}

pub fn openH5Group(h5Hndl: H5HID, path: g.String) H5HID { //todo H5HID or #f
    const v = path.toCStr(alloc) catch @trap();
    defer alloc.free(v);

    return H5HID.init(h5.H5Gopen1(h5Hndl.to(), v));
}

pub fn closeH5Group(h5GroupHndl: H5HID) void {
    _ = h5.H5Gclose(h5GroupHndl.to());
}

pub fn openH5Dataset(hndl: H5HID, path: g.String) H5HID {
    return H5HID.init(h5.H5Dopen2(hndl.to(), path.toCStr(alloc) catch @trap(), h5.H5P_DEFAULT));
}

pub fn closeH5Dataset(hndl: H5HID) void {
    _ = h5.H5Dclose(hndl.to());
}

//
//

const H5HID = g.SCMWrapper(struct {
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
});

const H5GInfo = g.SCMWrapper(struct {
    pub fn register() void {
        @This().registerType();

        _ = g.defineGSubRAndExport("h5-group-info", get);
        _ = g.defineGSubRAndExport("h5-group-info->string", toString);
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
});

//const sas: h5.H5L_iterate2_t = undefined;
// pub const H5L_iterate2_t = (group:h5.hid_t, name: [*c]const u8, info: [*c]const h5.H5L_info2_t, op_data:?*anyopaque) callconv(.C) h5.herr_t

const H5LInfo2 = g.SCMWrapper(struct {
    pub fn register() void {
        @This().registerType();

        _ = g.defineGSubRAndExport("link-info2->string", toString);
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
});

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
    return switch (h5.H5Pget_layout(plist_id.to())) {
        h5.H5D_COMPACT => g.Symbol.from("H5D-COMPACT"),
        h5.H5D_CONTIGUOUS => g.Symbol.from("H5D-CONTIGUOUS"),
        h5.H5D_CHUNKED => g.Symbol.from("H5D-CHUNKED"),
        h5.H5D_VIRTUAL => g.Symbol.from("H5D-VIRTUAL"),
        else => |_| {
            //todo actual error stuff
            return g.Symbol.from("ERROR");
        },
    };
}

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

pub fn getDatasetSpace(dataset_hndl: H5HID) H5HID {
    const out = h5.H5Dget_space(dataset_hndl.to());
    // can return H5I_INVALID_HID
    return H5HID.init(out);
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

fn getType(dataset_hndl: H5HID) H5HID {
    return H5HID.init(h5.H5Dget_type(dataset_hndl.to()));
}

// zig fmt: off
fn getTypeClass(type_hndl: H5HID) g.Symbol {
    return switch (h5.H5Tget_class(type_hndl.to())) {
        h5.H5T_NO_CLASS  => g.Symbol.from("H5T_NO_CLASS"),
        h5.H5T_INTEGER   => g.Symbol.from("H5T_INTEGER"),
        h5.H5T_FLOAT     => g.Symbol.from("H5T_FLOAT"),
        h5.H5T_TIME      => g.Symbol.from("H5T_TIME"),
        h5.H5T_STRING    => g.Symbol.from("H5T_STRING"),
        h5.H5T_BITFIELD  => g.Symbol.from("H5T_BITFIELD"),
        h5.H5T_OPAQUE    => g.Symbol.from("H5T_OPAQUE"),
        h5.H5T_COMPOUND  => g.Symbol.from("H5T_COMPOUND"),
        h5.H5T_REFERENCE => g.Symbol.from("H5T_REFERENCE"),
        h5.H5T_ENUM      => g.Symbol.from("H5T_ENUM"),
        h5.H5T_VLEN      => g.Symbol.from("H5T_VLEN"),
        h5.H5T_ARRAY     => g.Symbol.from("H5T_ARRAY"),
        h5.H5T_NCLASSES  => g.Symbol.from("H5T_NCLASSES"),
        else => g.Symbol.from("error"),
    };
}
// zig fmt: on

fn closeType(type_hndl: H5HID) void {
    _ = h5.H5Tclose(type_hndl.to());
}
//
////H5Tget_class => H%T_COMPOUND
//
//const H5T_TYPES = enum(h5.enum_H5T_class_t) {
//        H5T_NO_CLASS = H5T_NO_CLASS,
//        H5T_INTEGER  = H5T_INTEGER,
//        H5T_FLOAT
//        H5T_TIME
//        H5T_STRING
//        H5T_BITFIELD
//        H5T_OPAQUE
//        H5T_COMPOUND
//        H5T_REFERENCE
//        H5T_ENUM
//        H5T_VLEN
//        H5T_ARRAY
//        H5T_NCLASSES
//};
//
//
//pub fn RecreateEnum(tc: type, parms: anytype) type {
//
//}
//

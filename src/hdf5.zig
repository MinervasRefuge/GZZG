// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");
const gzzg = @import("gzzg");
const g = gzzg;

const guile = gzzg.guile; // BSD-3-Clause : Copyright © 2025 Abigale Raeck.

// zig fmt: off
pub const h5 = @cImport({
    // @cInclude("H5Apublic.h");   // Attributes (H5A)
    // @cInclude("H5Dpublic.h");   // Datasets (H5D)
    // @cInclude("H5Spublic.h");   // Dataspaces (H5S)
    // @cInclude("H5Tpublic.h");   // Datatypes (H5T)
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

export fn hello_world() guile.SCM {
    const out_port = guile.scm_current_output_port();
    const scmstr = guile.scm_from_utf8_string("Hello World!\n");

    return guile.scm_display(scmstr, out_port);
}

var gc = g.GuileGCAllocator{};
var alloc = gc.allocator();

export fn init_hdf5() void {
    _ = g.defineModule("hdf5", init_hdf5_module);
}

fn init_hdf5_module() void {
    _ = g.defineGSubRAndExport("hello-world", hello_world);
    _ = g.defineGSubRAndExport("open-h5", openH5);
    _ = g.defineGSubRAndExport("close-h5", closeH5);

    _ = g.defineGSubRAndExport("open-group", openH5Group);
    _ = g.defineGSubRAndExport("close-group", closeH5Group);

    _ = g.defineGSubRAndExport("group-links", getGroupsLinks);

    _ = g.defineGSubRAndExport("open-dataset", openH5Dataset);
    _ = g.defineGSubRAndExport("close-dataset", closeH5Dataset);

    H5HID.register();
    H5GInfo.register();

    H5LInfo2.register();
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
        if (@typeInfo(h5.hid_t).Int.bits == @typeInfo(usize).Int.bits) { // can I stuff the bits into the pointer
            return @This().makeSCM(@ptrFromInt(@as(usize, @bitCast(h))));
        } else {
            const p = @This().make(alloc) catch @trap();
            p.* = h;

            return @This().makeSCM(p);
        }
    }

    pub fn to(h: H5HID) h5.hid_t {
        H5HID.assert(h.s);

        if (@typeInfo(h5.hid_t).Int.bits == @typeInfo(usize).Int.bits) {
            return @bitCast(@intFromPtr(guile.scm_foreign_object_ref(h.s, 0)));
        } else {
            return @This().retrieve(h).?.*;
        }
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
    var l: g.List = g.List.init0();

    _ = h5.H5Lvisit2(group.to(), h5.H5_INDEX_NAME, h5.H5_ITER_NATIVE, linkIter, @ptrCast(&l));

    return l;
}

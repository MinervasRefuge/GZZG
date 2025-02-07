// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

// zig fmt: off

pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    const module_gzzg = b.addModule("gzzg", .{
        .root_source_file = b.path("src/gzzg.zig"),
        .target = target,
        .optimize = optimise,
        .link_libc = true, // todo: needed?
    });

    // Pathing issue patch
    const p = try std.process.getEnvVarOwned(alloc, "C_INCLUDE_PATH");
    defer alloc.free(p);
    const s = try std.fmt.allocPrint(alloc, "{s}/guile/3.0", .{p});
    defer alloc.free(s);
    
    module_gzzg.linkSystemLibrary("guile-3.0", .{});    
    module_gzzg.addIncludePath(.{ .cwd_relative = s });
    
    const test_step = b.step("test", "Run all the tests");

    // Is there a better way of declaring tests?
    const gzzg_vector_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "tests/test_vector.zig" },
        .target = target,
        .optimize = optimise,
        .single_threaded = true});

    gzzg_vector_test.root_module.addImport("gzzg", module_gzzg);

    test_step.dependOn(&b.addRunArtifact(gzzg_vector_test).step);
    //test_step.dependOn(&gzzg_test.step);
    
    const exe_gzzg = b.addExecutable(.{
        .name = "gzzg",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimise,
    });

    exe_gzzg.root_module.addImport("gzzg", module_gzzg);
    exe_gzzg.addIncludePath(.{ .cwd_relative = s }); // stop import problems in zls?

    const exe_snappy = b.addExecutable(.{
        .name = "snappy-test",
        .root_source_file = b.path("src/snappy.zig"),
        .target = target,
        .optimize = optimise,
    });

    const exe_sieve_example = b.addExecutable(.{
        .name = "sieve-example",
        .root_source_file = b.path("examples/sieve_of_Eratosthenes.zig"),
        .target = target,
        .optimize = optimise,
    });

    exe_sieve_example.root_module.addImport("gzzg", module_gzzg);

    const lib_gzzg_hdf5 = b.addSharedLibrary(.{
        .name = "gzzg-hdf5",
        .root_source_file = b.path("src/hdf5.zig"),
        .target = target,
        .optimize = optimise,
        .link_libc = true,
    });

    lib_gzzg_hdf5.root_module.addImport("gzzg", module_gzzg);
    lib_gzzg_hdf5.linkSystemLibrary("hdf5");


    const check = b.step("check", "Check if projects compiles");
    check.dependOn(&lib_gzzg_hdf5.step);

    b.installArtifact(exe_gzzg);
    b.installArtifact(exe_sieve_example);
    b.installArtifact(exe_snappy);
    b.installArtifact(lib_gzzg_hdf5);

    const run_gzzg_arti = b.addRunArtifact(exe_gzzg);
    const run_gzzg_step = b.step("run-gzzg", "Run the gzzg exe project");
    run_gzzg_step.dependOn(&run_gzzg_arti.step);

    const run_snappy_arti = b.addRunArtifact(exe_snappy);
    const run_snappy_step = b.step("run-snappy", "Run the snappy test exe proejct");
    run_snappy_step.dependOn(&run_snappy_arti.step);

    const run_build_scheme_step = b.step("build-gzzg-lib", "Build the gzzg project .so");

    run_build_scheme_step.dependOn(&lib_gzzg_hdf5.step);

    const run_scheme_step = b.step("run-gzzg-lib", "Run the gzzg project and load test-hdf5.scm file");
    const run_scheme = b.addSystemCommand(&.{"guile"});
    run_scheme.addArgs(&.{"--no-auto-compile", "-L", ".", "src/test-hdf5.scm"});

    //todo: fix, needs to be depended not run side by side.
    run_scheme_step.dependOn(run_build_scheme_step);
    run_scheme_step.dependOn(&run_scheme.step);
}

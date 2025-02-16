// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

// zig fmt: off

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    //b.option(bool, "enable_direct_string_access",
    //         "Enables direct Guile string access (possibly unstable)");
    
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_direct_string_access", true);

    const build_options_nondirect = b.addOptions();
    build_options_nondirect.addOption(bool, "enable_direct_string_access", false);

    const module_gzzg = b.addModule("gzzg", .{
        .root_source_file = b.path("src/gzzg.zig"),
        .target = target,
        .optimize = optimise,
        .link_libc = true,
    });

    const module_gzzg_nondirect = b.addModule("gzzg", .{
        .root_source_file = b.path("src/gzzg.zig"),
        .target = target,
        .optimize = optimise,
        .link_libc = true,
    });

    module_gzzg.addOptions("build_options", build_options);
    module_gzzg_nondirect.addOptions("build_options", build_options_nondirect);

    // Pathing issue patch
    const p = try std.process.getEnvVarOwned(b.allocator, "C_INCLUDE_PATH");
    defer b.allocator.free(p);
    const s = try std.fmt.allocPrint(b.allocator, "{s}/guile/3.0", .{p});
    defer b.allocator.free(s);
    
    module_gzzg.linkSystemLibrary("guile-3.0", .{});    
    module_gzzg.addIncludePath(.{ .cwd_relative = s });

    module_gzzg_nondirect.linkSystemLibrary("guile-3.0", .{});    
    module_gzzg_nondirect.addIncludePath(.{ .cwd_relative = s });
    
    const test_step = b.step("test", "Run all the tests");

    const gzzg_test_suite = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = target,
        .optimize = optimise,
        .single_threaded = true,
    });

    const gzzg_test_suite_nondirect = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = target,
        .optimize = optimise,
        .single_threaded = true,
    });
    
    gzzg_test_suite.root_module.addImport("gzzg", module_gzzg);
    gzzg_test_suite_nondirect.root_module.addImport("gzzg", module_gzzg_nondirect);

    const gzzg_test_suite_arti = b.addRunArtifact(gzzg_test_suite);
    const gzzg_test_suite_nondirect_arti = b.addRunArtifact(gzzg_test_suite_nondirect);

    test_step.dependOn(&gzzg_test_suite_arti.step);
    test_step.dependOn(&gzzg_test_suite_nondirect_arti.step);

    // is there a way for it to ouput the results of running the tests like pass and fail number?
    // currently the tests are not verbose as to what they tested.
    
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

    // Kcov works for zig via dwarf debug info. Downside is if the function is not used, it's not
    // listed in the dwarf and code coverage won't tell you otherwise. (100%)
    // So if there was a way to force zig to add in all functions regardless of usage, then this
    // might be of some use.
    //
    // `refAllDecls` sounds like it'll add in all the functions from a module, but it's hit and miss
    // as to how more coverage you actually get.
    const cov_step = b.step("cov", "Generate coverage");
  
    const cov_run = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/", "kcov-output-direct/" });
    cov_run.addArtifactArg(gzzg_test_suite);

    const cov_run_nondirect = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/", "kcov-output-nondirect/" });
    cov_run_nondirect.addArtifactArg(gzzg_test_suite_nondirect);

    const cov_merge = b.addSystemCommand(&.{ "kcov", "--merge", "kcov-output/", "kcov-output-direct/", "kcov-output-nondirect/"});

    cov_step.dependOn(&cov_merge.step);
    cov_merge.step.dependOn(&cov_run.step);
    cov_merge.step.dependOn(&cov_run_nondirect.step);


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

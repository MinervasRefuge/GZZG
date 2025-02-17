// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

const options = .{"enable_direct_string_access"};

pub fn build(b: *std.Build) !void {
    const module_gzzg = createModule(b);
    const module_gzzg_nondirect = createModule(b);

    const build_options = b.addOptions();
    build_options.addOption(bool, options[0], true);

    const build_options_nondirect = b.addOptions();
    build_options_nondirect.addOption(bool, options[0], false);

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

    //

    const examples_step = b.step("examples", "Build all examples");
    buildExamples(b, examples_step, module_gzzg);

    const test_step = b.step("test", "Run all the tests");
    const test_suite = buildTests(b, test_step, module_gzzg);
    const test_suite_nondirect = buildTests(b, test_step, module_gzzg_nondirect);

    //

    const cov_step = b.step("cov", "Generate coverage over tests");
    const cov_merge = b.addSystemCommand(&.{ "kcov", "--merge", "kcov-output/", "kcov-output-direct/", "kcov-output-nondirect/" });

    cov_step.dependOn(&cov_merge.step);
    covOver(b, &cov_merge.step, test_suite, "kcov-output-direct/");
    covOver(b, &cov_merge.step, test_suite_nondirect, "kcov-output-nondirect/");
}

//
//
//

fn getTargetOptions(b: *std.Build) std.Build.ResolvedTarget {
    const container = struct {
        var singleton: ?std.Build.ResolvedTarget = null;
    };

    if (container.singleton == null) {
        container.singleton = b.standardTargetOptions(.{});
    }

    return container.singleton.?;
}

fn getOptimiseOptions(b: *std.Build) std.builtin.OptimizeMode {
    const container = struct {
        var singleton: ?std.builtin.OptimizeMode = null;
    };

    if (container.singleton == null) {
        container.singleton = b.standardOptimizeOption(.{});
    }

    return container.singleton.?;
}

fn createModule(b: *std.Build) *std.Build.Module {
    return b.addModule("gzzg", .{
        .root_source_file = b.path("src/gzzg.zig"),
        .target = getTargetOptions(b),
        .optimize = getOptimiseOptions(b),
        .link_libc = true,
    });
}

fn buildExamples(b: *std.Build, step: *std.Build.Step, module_gzzg: *std.Build.Module) void {
    const target = getTargetOptions(b);
    const optimise = getOptimiseOptions(b);

    const example_allsorts = b.addExecutable(.{
        .name = "example-allsorts",
        .root_source_file = b.path("examples/allsorts.zig"),
        .target = target,
        .optimize = optimise,
    });

    const example_sieve = b.addExecutable(.{
        .name = "example-sieve",
        .root_source_file = b.path("examples/sieve_of_Eratosthenes.zig"),
        .target = target,
        .optimize = optimise,
    });

    example_allsorts.root_module.addImport("gzzg", module_gzzg);
    example_sieve.root_module.addImport("gzzg", module_gzzg);

    b.installArtifact(example_allsorts);
    b.installArtifact(example_sieve);

    step.dependOn(&example_allsorts.step);
    step.dependOn(&example_sieve.step);
}

fn buildTests(b: *std.Build, step: *std.Build.Step, module_gzzg: *std.Build.Module) *std.Build.Step.Compile {
    // is there a way for it to ouput the results of running the tests like pass and fail number?
    // currently the tests are not verbose as to what they tested.

    const test_suite = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = getTargetOptions(b),
        .optimize = getOptimiseOptions(b),
        .single_threaded = true,
    });

    test_suite.root_module.addImport("gzzg", module_gzzg);

    const test_suite_arti = b.addRunArtifact(test_suite);
    step.dependOn(&test_suite_arti.step);

    return test_suite;
}

fn covOver(b: *std.Build, step: *std.Build.Step, test_suite: *std.Build.Step.Compile, out: [:0]const u8) void {
    // Kcov works for zig via dwarf debug info. Downside is if the function is not used, it's not
    // listed in the dwarf and code coverage won't tell you otherwise. (100%)
    // So if there was a way to force zig to add in all functions regardless of usage, then this
    // might be of some use.
    //
    // `refAllDecls` sounds like it'll add in all the functions from a module, but it's hit and miss
    // as to how more coverage you actually get.
    const cmd = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/", out });
    cmd.addArtifactArg(test_suite);

    step.dependOn(&cmd.step);
}

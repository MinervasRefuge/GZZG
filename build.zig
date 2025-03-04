// BSD-3-Clause : Copyright © 2025 Abigale Raeck.

const std = @import("std");

// zig fmt: off
const gzzg_options = .{
    "enable_direct_string_access",
    "enable_comptime_number_creation",
    "enable_iw_smob",
    "trust_iw_consts",
};
// zig fmt: on

pub fn build(b: *std.Build) !void {
    const module_gzzg = createModule(b);
    const module_gzzg_nondirect = createModule(b);
    const module_guile = produceGuileModule(b);

    module_gzzg.addImport("guile", module_guile);
    module_gzzg_nondirect.addImport("guile", module_guile);

    const build_options = b.addOptions();
    build_options.addOption(bool, gzzg_options[0], true);
    build_options.addOption(bool, gzzg_options[1], true);
    build_options.addOption(bool, gzzg_options[2], true);
    build_options.addOption(bool, gzzg_options[3], true);

    const build_options_nondirect = b.addOptions();
    build_options_nondirect.addOption(bool, gzzg_options[0], false);
    build_options_nondirect.addOption(bool, gzzg_options[1], false);
    build_options_nondirect.addOption(bool, gzzg_options[2], false);
    build_options_nondirect.addOption(bool, gzzg_options[3], false);

    module_gzzg.addOptions("build_options", build_options);
    module_gzzg_nondirect.addOptions("build_options", build_options_nondirect);

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

// todo: make as an external callable function
fn produceGuileModule(b: *std.Build) *std.Build.Module {
    const envp = std.process.getEnvVarOwned(b.allocator, "C_INCLUDE_PATH") catch @panic("ENV!");
    defer b.allocator.free(envp);

    // can pkg-conf come into play here, rather than doing this manually.
    var path_header: ?[]u8 = null;
    var path_include: []u8 = undefined;
    var itr_h = std.mem.splitScalar(u8, envp, ':');
    while (itr_h.next()) |p| {
        const full_path = b.fmt("{s}/guile/3.0/libguile.h", .{p});
        std.fs.accessAbsolute(full_path, .{}) catch continue;

        path_header = full_path;
        path_include = b.fmt("{s}/guile/3.0", .{p});
        break;
    }

    var trans = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = path_header.? },
        .link_libc = true,
        .target = getTargetOptions(b),
        .optimize = getOptimiseOptions(b), //
    });

    trans.addIncludeDir(path_include);

    var clean_trans = SourceCleaner.create(b, .{ .translation_path = trans.getOutput() });

    const gmod = clean_trans.addModule("guile");
    gmod.resolved_target = getTargetOptions(b);
    gmod.optimize = getOptimiseOptions(b);
    gmod.linkSystemLibrary("guile-3.0", .{ .needed = true });

    return gmod;
}

// SourceCleaner hides a few invalid functions from the c-translated header.
// Helpful for dev purposes, though not needed for external libs
const SourceCleaner = struct {
    step: std.Build.Step,
    source: std.Build.LazyPath,
    output_file: std.Build.GeneratedFile,
    file_name: []const u8,

    const Options = struct { translation_path: std.Build.LazyPath };

    pub fn create(owner: *std.Build, options: Options) *SourceCleaner {
        const cleaner = owner.allocator.create(SourceCleaner) catch @panic("OOM");
        const source = options.translation_path.dupe(owner);

        cleaner.* = SourceCleaner{
            .step = std.Build.Step.init(.{
                .id = std.Build.Step.Id.custom,
                .name = "trim-guile_c-translate", //
                .owner = owner,
                .makeFn = make,
            }),
            .source = source,
            .output_file = .{ .step = &cleaner.step },
            .file_name = "c-out.zig",
        };

        source.addStepDependencies(&cleaner.step);

        return cleaner;
    }

    pub fn getOutput(cleaner: *SourceCleaner) std.Build.LazyPath {
        return .{ .generated = .{ .file = &cleaner.output_file } };
    }

    pub fn addModule(cleaner: *SourceCleaner, name: []const u8) *std.Build.Module {
        return cleaner.step.owner.addModule(name, .{
            .root_source_file = cleaner.getOutput(),
        });
    }

    fn make(step: *std.Build.Step, prog_node: std.Progress.Node) !void {
        _ = prog_node;
        const b = step.owner;
        const cleaner: *SourceCleaner = @fieldParentPtr("step", step);

        const full_source: [:0]u8 = initialisation: {
            const path = cleaner.source.getPath2(b, step);
            const file_zig = std.fs.openFileAbsolute(path, .{}) catch @panic("missing file");
            defer file_zig.close();

            break :initialisation file_zig.readToEndAllocOptions(b.allocator, 500_000, null, @alignOf(u8), 0) catch @panic("Bleh");
        };

        // parse ast and modify the full_source to remove the `pub` tags
        {
            var ast = std.zig.Ast.parse(b.allocator, full_source, .zig) catch unreachable;
            defer ast.deinit(b.allocator);

            for (ast.rootDecls()) |node_idx| {
                var buffer: [1]std.zig.Ast.Node.Index = undefined;

                if (ast.fullFnProto(&buffer, node_idx)) |ffp| {
                    const fn_name = ast.tokenSlice(ffp.name_token.?);

                    if (std.mem.startsWith(u8, fn_name, "scm_i_") or
                        std.mem.startsWith(u8, fn_name, "SCM_I_"))
                    {
                        const pub_token = ast.tokens.get(ffp.visib_token.?);

                        @memset(full_source[pub_token.start..][0..3], ' ');
                    }
                }
            }
        }

        // Setup caching checks
        var man = b.graph.cache.obtain();
        defer man.deinit();

        man.hash.add(std.fmt.bytesToHex("ice-9", .upper));
        man.hash.addBytes(full_source);

        if (try step.cacheHit(&man)) {
            const digest = man.final();

            cleaner.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, cleaner.file_name });

            return;
        }

        // write out file since the cache didn't hit.
        const digest = man.final();
        const cache_path = "o" ++ std.fs.path.sep_str ++ digest;

        var cache_dir = try b.cache_root.handle.makeOpenPath(cache_path, .{});
        defer cache_dir.close();

        const out_file = try cache_dir.createFile(cleaner.file_name, .{});
        defer out_file.close();
        try out_file.writeAll(full_source);

        cleaner.output_file.path = try b.cache_root.join(b.allocator, &.{ cache_path, cleaner.file_name });

        //

        try step.writeManifest(&man);
    }
};

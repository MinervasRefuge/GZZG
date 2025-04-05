// BSD-3-Clause : Copyright © 2025 Abigale Raeck.
// zig fmt: off

const std    = @import("std");
const Import = std.Build.Module.Import;

const gzzg_options = .{
    "enable_direct_string_access",
    "enable_comptime_number_creation",
    "enable_iw_smob",
    "trust_iw_consts",
    "has_bytecode_module",
};

pub fn build(b: *std.Build) !void {
    const module_gzzg = createModule(b);
    const module_gzzg_nondirect = createModule(b);

    // todo: extract bytecode module creation to own function 
    const extract_bytecode = b.option(bool, "extract-bytecode",
                                       "Extract Guile bytecodes via (language bytecode)")
        orelse false;
    
    if (extract_bytecode) {
        const cmd = b.addSystemCommand(&.{"guile", "--no-auto-compile"});
        cmd.addFileArg(b.path("src/extract-bytecodes.scm"));

        const module_bytecode = b.addModule("bytecode", .{
            .root_source_file = cmd.captureStdOut(),
            .target = getTargetOptions(b),
            .optimize = getOptimiseOptions(b)
        });

        module_gzzg.addImport("bytecode", module_bytecode);
        module_gzzg_nondirect.addImport("bytecode", module_bytecode);
    }

    const build_options = b.addOptions();
    build_options.addOption(bool, gzzg_options[0], true);
    build_options.addOption(bool, gzzg_options[1], true);
    build_options.addOption(bool, gzzg_options[2], true);
    build_options.addOption(bool, gzzg_options[3], true);
    build_options.addOption(bool, gzzg_options[4], extract_bytecode);

    const build_options_nondirect = b.addOptions();
    build_options_nondirect.addOption(bool, gzzg_options[0], false);
    build_options_nondirect.addOption(bool, gzzg_options[1], false);
    build_options_nondirect.addOption(bool, gzzg_options[2], false);
    build_options_nondirect.addOption(bool, gzzg_options[3], false);
    build_options_nondirect.addOption(bool, gzzg_options[4], extract_bytecode);

    module_gzzg.addOptions("build_options", build_options);
    module_gzzg_nondirect.addOptions("build_options", build_options_nondirect);

    //

    const examples_step = b.step("examples", "Build all examples");
    buildExamples(b, examples_step, module_gzzg);

    const test_step = b.step("test", "Run all the tests");
    const test_suite_nondirect = buildExternalTests(b, test_step, module_gzzg_nondirect);
    const test_suite           = buildExternalTests(b, &test_suite_nondirect.step, module_gzzg);
    const test_gzzg_nondirect  = buildInternalTests(b, &test_suite.step, module_gzzg_nondirect);
    const test_gzzg            = buildInternalTests(b, &test_gzzg_nondirect.step, module_gzzg);

    //todo add to cov
    _ = test_gzzg;

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
        .imports = &[_]Import{.{ .name = "guile", .module = produceGuileModule(b) }},
    });
}

fn buildExamples(b: *std.Build, step: *std.Build.Step, module_gzzg: *std.Build.Module) void {
    const target = getTargetOptions(b);
    const optimise = getOptimiseOptions(b);

    const examples = [_]*std.Build.Step.Compile{
        b.addExecutable(.{
            .name = "example-allsorts",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/allsorts.zig"),
                .target = target,
                .optimize = optimise,
                .imports = &[_]Import{.{ .name = "gzzg", .module = module_gzzg }},
            }),
        }),
        b.addExecutable(.{
            .name = "example-sieve",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/sieve_of_Eratosthenes.zig"),
                .target = target,
                .optimize = optimise,
                .imports = &[_]Import{.{ .name = "gzzg", .module = module_gzzg }},
            }),
        }),
        b.addExecutable(.{
            .name = "example-monte-carlo-pi",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/monte_carlo_pi.zig"),
                .target = target,
                .optimize = optimise,
                .imports = &[_]Import{.{ .name = "gzzg", .module = module_gzzg }},
            }),
        }),
    };

    for (examples) |example| {
        b.installArtifact(example);
        step.dependOn(&example.step);
    }
}

fn buildExternalTests(b: *std.Build, step: *std.Build.Step, module_gzzg: *std.Build.Module) *std.Build.Step.Compile {
    // is there a way for it to ouput the results of running the tests like pass and fail number?
    // currently the tests are not verbose as to what they tested.

    const test_suite = b.addTest(.{ //
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = getTargetOptions(b),
            .optimize = getOptimiseOptions(b),
            .single_threaded = true,
            .imports = &[_]Import{.{ .name = "gzzg", .module = module_gzzg }},
        }),
    });

    const test_suite_arti = b.addRunArtifact(test_suite);
    step.dependOn(&test_suite_arti.step);

    return test_suite;
}

fn buildInternalTests(b: *std.Build, step: *std.Build.Step, module_gzzg: *std.Build.Module) *std.Build.Step.Compile {
    const test_gzzg = b.addTest(.{ //
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gzzg.zig"),
            .target = getTargetOptions(b),
            .optimize = getOptimiseOptions(b),
            .link_libc = true,
            .single_threaded = true,
        }),
    });
    
    for (module_gzzg.import_table.keys()) |key| {
        test_gzzg.root_module.addImport(key, module_gzzg.import_table.get(key).?);
    }

    const test_gzzg_arti = b.addRunArtifact(test_gzzg);
    step.dependOn(&test_gzzg_arti.step);

    return test_gzzg;
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

fn produceGuileModule(b: *std.Build) *std.Build.Module {
    const lib      = "guile-3.0";
    const sub_path = "/guile/3.0";
    
    var slstep = SystemLibraryIncludePath.create(b, lib, sub_path);
    var trans  = b.addTranslateC(.{
        .root_source_file = slstep.getOutputWithSubPath("libguile.h"),
        .link_libc        = true,
        .target           = getTargetOptions(b),
        .optimize         = getOptimiseOptions(b), 
    });

    trans.addIncludePath(slstep.getOutput());

    var clean_trans      = SourceCleaner.create(b, .{ .translation_path = trans.getOutput() });
    const gmod           = clean_trans.addModule("guile");
    gmod.resolved_target = getTargetOptions(b);
    gmod.optimize        = getOptimiseOptions(b);
    gmod.linkSystemLibrary(lib, .{ .needed = true });

    return gmod;
}

// ~std.Build.Step.Compile.execPkgConfigList~ isn't public or really accsessable via a build step dep.
// dup as it's own step.
const SystemLibraryIncludePath = struct {
    step: std.Build.Step,
    pkg_name: []const u8,
    append: [] const u8,
    output_dir: std.Build.GeneratedFile,

    pub fn getOutput(self: *@This()) std.Build.LazyPath {
        return .{ .generated = .{ .file = &self.output_dir } };
    }

    pub fn getOutputWithSubPath(self: *@This(), sub_path: []const u8) std.Build.LazyPath { 
        return .{  .generated = .{ .file = &self.output_dir, .sub_path = sub_path } };
    }

    pub fn create(owner: *std.Build, pkg:[] const u8, append_path: []const u8) *@This() {
        const l = owner.allocator.create(@This()) catch @panic("OOM");

        l.* = .{
            .step = std.Build.Step.init(.{
                .id = std.Build.Step.Id.custom,
                .name = owner.fmt("find pkg {s} for path {s}", .{pkg, append_path}),
                .owner = owner,
                .makeFn = make,
            }),
            .output_dir = .{ .step = &l.step },
            .pkg_name = pkg,
            .append = append_path,
        };

        return l;
    }

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
        const b = step.owner;
        const self: *@This() = @fieldParentPtr("step", step);

        // todo: better error checking
        const pkg_config_exe = b.graph.env_map.get("PKG_CONFIG") orelse "pkg-config";
        //const stdout = try b.runAllowFail(&[_][]const u8{ pkg_config_exe, "--list-all" }, out_code, .Ignore);
        
        const result = std.process.Child.run(.{
            .allocator = b.allocator,
            .argv = &.{pkg_config_exe, self.pkg_name, "--variable=includedir"},
            .progress_node = options.progress_node // or is this meant to be .start() (for a child progress node)?
        })  catch |err| {
            return step.fail("unable to find pkg '{s}': {s}", .{
                self.pkg_name, @errorName(err),
            });
        };
        defer b.allocator.free(result.stdout);
        defer b.allocator.free(result.stderr); //todo stderr ?

        var line = std.mem.tokenizeAny(u8, result.stdout, "\r\n");

        self.output_dir.path = b.fmt("{s}{s}", .{line.next().?, self.append});
    }
};

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

    fn make(step: *std.Build.Step, options: std.Build.Step.MakeOptions) !void {
        _ = options;
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

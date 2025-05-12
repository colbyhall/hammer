const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gpu_mod = b.createModule(.{
        .root_source_file = b.path("src/gpu/gpu.zig"),
        .target = target,
        .optimize = optimize,
    });
    gpu_mod.addImport("core", core_mod);

    gpu_mod.addCSourceFile(.{
        .file = b.path("src/gpu/drivers/metal/metal.m"),
        .language = .objective_c,
    });
    gpu_mod.addIncludePath(b.path("src/gpu/drivers/metal/"));
    gpu_mod.linkSystemLibrary("objc", .{});
    gpu_mod.linkFramework("appkit", .{});
    gpu_mod.linkFramework("metal", .{});

    const sandbox_mod = b.createModule(.{
        .root_source_file = b.path("src/sandbox/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    sandbox_mod.addImport("core", core_mod);
    sandbox_mod.addImport("gpu", gpu_mod);

    const sandbox = b.addExecutable(.{
        .name = "sandbox",
        .root_module = sandbox_mod,
    });

    b.installArtifact(sandbox);

    const run_cmd = b.addRunArtifact(sandbox);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = core_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = sandbox_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

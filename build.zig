//! Use `zig init --strip` next time to generate a project without comments.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const system_tray = b.option(bool, "system-tray", "Enable system tray integration") orelse false;
    const testing = b.option(bool, "testing", "Build for testing (headless CI)") orelse false;

    // Dependencies
    const flash_dep = b.dependency("flash", .{
        .target = target,
        .optimize = optimize,
    });

    const ghostnv_dep = b.dependency("ghostnv", .{
        .target = target,
        .optimize = optimize,
    });

    const phantom_dep = b.dependency("phantom", .{
        .target = target,
        .optimize = optimize,
    });

    const jaguar_dep = if (!testing) b.dependency("jaguar", .{
        .target = target,
        .optimize = optimize,
    }) else null;

    // Create the main library module
    const nvctl_mod = b.addModule("nvctl", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to the module
    nvctl_mod.addImport("flash", flash_dep.module("flash"));
    nvctl_mod.addImport("ghostnv", ghostnv_dep.module("ghostnv"));
    nvctl_mod.addImport("phantom", phantom_dep.module("phantom"));
    if (jaguar_dep) |jag| {
        nvctl_mod.addImport("jaguar", jag.module("jaguar"));
    }

    // Main executable
    const exe = b.addExecutable(.{
        .name = "nvctl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to executable
    exe.root_module.addImport("nvctl", nvctl_mod);
    exe.root_module.addImport("flash", flash_dep.module("flash"));
    exe.root_module.addImport("ghostnv", ghostnv_dep.module("ghostnv"));
    exe.root_module.addImport("phantom", phantom_dep.module("phantom"));
    if (jaguar_dep) |jag| {
        exe.root_module.addImport("jaguar", jag.module("jaguar"));
    }

    // Add build options
    const options = b.addOptions();
    options.addOption(bool, "system_tray", system_tray);
    options.addOption(bool, "testing", testing);
    exe.root_module.addOptions("nvctl_options", options);

    // Link system libraries
    exe.linkLibC();
    if (!testing) {
        // Only link GUI libraries in non-testing builds
        if (target.result.os.tag == .linux) {
            exe.linkSystemLibrary("gtk+-3.0");
            exe.linkSystemLibrary("glib-2.0");
        }
    }

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options to tests
    lib_unit_tests.root_module.addOptions("nvctl_options", options);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

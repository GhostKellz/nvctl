const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const system_tray = b.option(bool, "system-tray", "Enable system tray integration") orelse false;
    const testing = b.option(bool, "testing", "Build for testing (headless CI)") orelse false;

    // Create build options
    const options = b.addOptions();
    options.addOption(bool, "system_tray", system_tray);
    options.addOption(bool, "testing", testing);

    // Main executable (simplified without external dependencies for now)
    const exe = b.addExecutable(.{
        .name = "nvctl",
        .root_source_file = b.path("src/main_simple.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options
    exe.root_module.addOptions("build_options", options);

    // Link system libraries
    exe.linkLibC();

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
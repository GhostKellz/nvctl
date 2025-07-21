const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl_options = @import("nvctl_options");

const nvctl = @import("nvctl");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // If no arguments provided, launch GUI (if available)
    if (args.len <= 1) {
        if (nvctl_options.testing) {
            try printHelp();
            return;
        }

        // Launch GUI
        try nvctl.gui.launch(allocator);
        return;
    }

    // Simple command parsing
    const command = args[1];
    
    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp();
    } else if (std.mem.eql(u8, command, "gpu")) {
        try handleGpuCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "display")) {
        try handleDisplayCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "overclock")) {
        try handleOverclockCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "vrr")) {
        try handleVrrCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "upscaling")) {
        try handleUpscalingCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "drivers")) {
        try handleDriversCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "fan")) {
        try handleFanCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "power")) {
        try handlePowerCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "gamescope")) {
        try handleGamescopeCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "monitor")) {
        try handleMonitorCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "stress")) {
        try handleStressTestCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "performance")) {
        try handlePerformanceCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version")) {
        try printVersion();
    } else {
        try nvctl.utils.print.format("Unknown command: {s}\n", .{command});
        try printHelp();
    }
}

fn printHelp() !void {
    try nvctl.utils.print.line("nvctl - NVIDIA GPU Control Tool\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  gpu         GPU monitoring and information");
    try nvctl.utils.print.line("  display     Display management and configuration");
    try nvctl.utils.print.line("  overclock   GPU overclocking controls");
    try nvctl.utils.print.line("  vrr         Variable refresh rate management");
    try nvctl.utils.print.line("  upscaling   DLSS/FSR/XeSS configuration");
    try nvctl.utils.print.line("  drivers     Driver installation and management");
    try nvctl.utils.print.line("  fan         Fan control and monitoring");
    try nvctl.utils.print.line("  power       Advanced power management");
    try nvctl.utils.print.line("  gamescope   Gaming compositor integration");
    try nvctl.utils.print.line("  monitor     Advanced monitoring and alerting");
    try nvctl.utils.print.line("  stress      Hardware validation and stress testing");
    try nvctl.utils.print.line("  performance Performance optimization and profiling");
    try nvctl.utils.print.line("  version     Show version information");
    try nvctl.utils.print.line("  help        Show help information\n");
    try nvctl.utils.print.line("For more information on a specific command, run:");
    try nvctl.utils.print.line("  nvctl <COMMAND> help");
}

fn handleGpuCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.gpu.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.gpu.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleDisplayCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.display.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.display.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleOverclockCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.overclocking.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.overclocking.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleVrrCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.vrr.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.vrr.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleUpscalingCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.upscaling.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.upscaling.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleDriversCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.drivers.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.drivers.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleFanCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.fan.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.fan.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handlePowerCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.power.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.power.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleGamescopeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.gamescope.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.gamescope.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleMonitorCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.monitoring.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.monitoring.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handleStressTestCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.stress_test.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.stress_test.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn handlePerformanceCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try nvctl.performance.handleCommand(allocator, null);
        return;
    }
    
    const subcommand = args[1];
    try nvctl.performance.handleCommandSimple(allocator, subcommand, args[2..]);
}

fn printVersion() !void {
    try nvctl.utils.print.line("nvctl 0.1.0 - Pure Zig NVIDIA GPU Control Tool");
    try nvctl.utils.print.line("Built with Zig 0.15.0");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Dependencies:");
    try nvctl.utils.print.line("  • ghostnv: NVIDIA open driver (575.0.0-ghost)");
    try nvctl.utils.print.line("  • phantom: TUI framework");
    try nvctl.utils.print.line("  • flash: CLI framework");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Repository: https://github.com/ghostkellz/nvctl");
    try nvctl.utils.print.line("Maintainer: Christopher Kelley <ckelley@ghostkellz.sh>");
    try nvctl.utils.print.line("License: MIT");
}
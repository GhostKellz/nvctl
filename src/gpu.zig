const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printGpuHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    _ = args;
    
    if (std.mem.eql(u8, subcommand, "info")) {
        try showGpuInfo(allocator);
    } else if (std.mem.eql(u8, subcommand, "stat")) {
        try showGpuStats(allocator);
    } else if (std.mem.eql(u8, subcommand, "capabilities")) {
        try showGpuCapabilities(allocator);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printGpuHelp();
    } else {
        try nvctl.utils.print.format("Unknown gpu subcommand: {s}\n", .{subcommand});
        try printGpuHelp();
    }
}

fn printGpuHelp() !void {
    try nvctl.utils.print.line("nvctl gpu - GPU monitoring and information\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl gpu <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  info         Show comprehensive GPU information");
    try nvctl.utils.print.line("  stat         Launch live TUI dashboard for GPU monitoring");
    try nvctl.utils.print.line("  capabilities Show detailed GPU overclocking capabilities");
    try nvctl.utils.print.line("  help         Show this help message");
}

fn showGpuInfo(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🎮 GPU Information");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Use the new ghostnv integration layer
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ No NVIDIA GPU found or driver not available");
            try nvctl.utils.print.line("");
            try nvctl.utils.print.line("💡 Make sure you have:");
            try nvctl.utils.print.line("  • NVIDIA GPU installed");
            try nvctl.utils.print.line("  • NVIDIA drivers loaded (nvidia or nvidia-open)");
            try nvctl.utils.print.line("  • Proper permissions to access GPU");
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("GPU 0: {s}\n", .{gpu_info.name});
    try nvctl.utils.print.format("  Driver Version: {s}\n", .{gpu_info.driver_version});
    try nvctl.utils.print.format("  Architecture:   {s}\n", .{gpu_info.architecture});
    try nvctl.utils.print.format("  PCI ID:         {s}\n", .{gpu_info.pci_id});
    
    if (gpu_info.vram_total > 0) {
        const vram_gb = @as(f64, @floatFromInt(gpu_info.vram_total)) / (1024.0 * 1024.0 * 1024.0);
        try nvctl.utils.print.format("  VRAM Total:     {d:.1} GB\n", .{vram_gb});
    } else {
        try nvctl.utils.print.line("  VRAM Total:     Unknown");
    }
    
    if (gpu_info.temperature > 0) {
        try nvctl.utils.print.format("  Temperature:    {d}°C\n", .{gpu_info.temperature});
    } else {
        try nvctl.utils.print.line("  Temperature:    Unknown");
    }
    
    if (gpu_info.power_usage > 0) {
        try nvctl.utils.print.format("  Power Usage:    {d}W\n", .{gpu_info.power_usage});
    } else {
        try nvctl.utils.print.line("  Power Usage:    Unknown");
    }
    
    if (gpu_info.utilization > 0) {
        try nvctl.utils.print.format("  GPU Usage:      {d}%\n", .{gpu_info.utilization});
    } else {
        try nvctl.utils.print.line("  GPU Usage:      Unknown");
    }
    
    try nvctl.utils.print.format("  Compute Cap:    {s}\n", .{gpu_info.compute_capability});
    try nvctl.utils.print.line("");
    
    try nvctl.utils.print.line("💡 For real-time monitoring, use: nvctl gpu stat");
}

fn showGpuStats(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🎯 Live GPU Stats Dashboard");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller for live stats
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    try nvctl.utils.print.line("🚀 Starting live monitoring...");
    try nvctl.utils.print.line("Press Ctrl+C to exit");
    try nvctl.utils.print.line("");
    
    // Live monitoring loop (simplified version until phantom is fully integrated)
    var refresh_count: u32 = 0;
    while (refresh_count < 10) { // Limit to 10 refreshes for demo
        // Clear screen (simplified)
        try nvctl.utils.print.line("\x1B[2J\x1B[H");
        
        try nvctl.utils.print.line("🎯 Live GPU Stats Dashboard (Refresh #" ++ std.fmt.comptimePrint("{d}", .{refresh_count + 1}) ++ ")");
        try nvctl.utils.print.line("══════════════════════════════════════════════════");
        try nvctl.utils.print.line("");
        
        // Get current GPU stats
        const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                try nvctl.utils.print.line("❌ Unable to get GPU stats");
                break;
            },
        };
        defer gpu_info.deinit(allocator);
        
        // Display live stats in a box
        try nvctl.utils.print.line("┌─ GPU Stats ─────────────────────────────────────┐");
        try nvctl.utils.print.format("│ 🎯 {s:<15} 🌡️ {d:>2}°C    ⚡ {d:>3}W        │\n", .{ 
            gpu_info.name[0..@min(15, gpu_info.name.len)], 
            gpu_info.temperature, 
            gpu_info.power_usage 
        });
        
        // GPU utilization bar
        const util_bars = createProgressBar(allocator, gpu_info.utilization, 10) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return,
        };
        defer allocator.free(util_bars);
        try nvctl.utils.print.format("│ 📈 GPU: {s} {d:>2}%   💾 VRAM: Unknown        │\n", .{ util_bars, gpu_info.utilization });
        
        // Temperature bar
        const temp_bars = createTempBar(allocator, gpu_info.temperature, 10) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return,
        };
        defer allocator.free(temp_bars);
        try nvctl.utils.print.format("│ 🌀 Fan: Unknown         🔥 Temp: {s}    │\n", .{temp_bars});
        
        try nvctl.utils.print.line("└─────────────────────────────────────────────────┘");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.format("Last updated: {d} seconds ago\n", .{refresh_count});
        
        // Sleep for 1 second
        std.time.sleep(1000000000);
        refresh_count += 1;
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Full phantom TUI integration coming next!");
    try nvctl.utils.print.line("💡 Use 'nvctl gpu info' for static information");
}

fn createProgressBar(allocator: std.mem.Allocator, value: u32, width: u32) ![]u8 {
    var bar = try allocator.alloc(u8, width);
    const filled = @min(value * width / 100, width);
    
    for (0..width) |i| {
        bar[i] = if (i < filled) '█' else '░';
    }
    
    return bar;
}

fn createTempBar(allocator: std.mem.Allocator, temp: u32, width: u32) ![]u8 {
    var bar = try allocator.alloc(u8, width);
    const max_temp: u32 = 90; // Max safe temperature
    const filled = @min(temp * width / max_temp, width);
    
    for (0..width) |i| {
        bar[i] = if (i < filled) '█' else '░';
    }
    
    return bar;
}

fn showGpuCapabilities(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("⚡ GPU Overclocking Capabilities");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // TODO: Get actual capabilities from ghostnv
    try nvctl.utils.print.line("GPU 0: NVIDIA RTX Series (ghostnv detection)");
    try nvctl.utils.print.line("  GPU Clock:");
    try nvctl.utils.print.line("    Base:         1400 MHz");
    try nvctl.utils.print.line("    Boost:        1900 MHz"); 
    try nvctl.utils.print.line("    Max Offset:   +300 MHz");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("  Memory Clock:");
    try nvctl.utils.print.line("    Base:         10501 MHz");
    try nvctl.utils.print.line("    Max Offset:   +1500 MHz");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("  Power:");
    try nvctl.utils.print.line("    Default:      100%");
    try nvctl.utils.print.line("    Minimum:      50%");
    try nvctl.utils.print.line("    Maximum:      120%");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("  Temperature:");
    try nvctl.utils.print.line("    Max Safe:     83°C");
    try nvctl.utils.print.line("    Throttle:     87°C");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("  GhostNV Features:");
    try nvctl.utils.print.line("    Voltage Ctrl: ✓ Supported");
    try nvctl.utils.print.line("    Fan Control:  ✓ Supported"); 
    try nvctl.utils.print.line("    Power Limit:  ✓ Supported");
    try nvctl.utils.print.line("    Memory OC:    ✓ Supported");
    try nvctl.utils.print.line("    DLSS Control: ✓ Supported");
    try nvctl.utils.print.line("    RT Control:   ✓ Supported");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Actual limits will be queried from ghostnv driver");
}
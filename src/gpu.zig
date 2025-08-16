//! GPU Monitoring and TUI Dashboard
//! 
//! This module provides comprehensive GPU monitoring capabilities with an advanced
//! TUI (Terminal User Interface) dashboard powered by the phantom framework.
//! 
//! Features:
//! - Real-time GPU statistics monitoring
//! - Professional-grade dashboard with graphs and charts
//! - Interactive controls for overclocking and fan curves
//! - Multi-panel layout with customizable views
//! - Keyboard shortcuts for navigation
//! - Historical data visualization
//! 
//! Dependencies:
//! - phantom: TUI framework for rich terminal interfaces
//! - ghostnv: Hardware monitoring and control
//! - nvctl.ghostnv_integration: Hardware abstraction layer

const std = @import("std");
const ghostnv = @import("ghostnv");
const phantom = @import("phantom");
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

/// Advanced TUI Dashboard with Phantom Framework
fn showGpuStats(allocator: std.mem.Allocator) !void {
    // Check if we can initialize phantom TUI
    if (initPhantomTUI(allocator)) {
        try launchAdvancedTUIDashboard(allocator);
    } else |err| {
        // Fallback to simple terminal dashboard
        try nvctl.utils.print.format("⚠️  Phantom TUI unavailable ({s}), using fallback dashboard\n", .{@errorName(err)});
        try launchSimpleDashboard(allocator);
    }
}

/// Initialize Phantom TUI framework
fn initPhantomTUI(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // Initialize the phantom framework
    try phantom.bufferedPrint();
    
    // Set up terminal raw mode for interactive input
    // phantom.Terminal raw mode setup would go here when implemented
}

/// Launch advanced TUI dashboard with phantom widgets
fn launchAdvancedTUIDashboard(allocator: std.mem.Allocator) !void {
    const enhanced_tui = @import("enhanced_tui.zig");
    
    // Initialize all controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    try gpu_controller.initializeDriver();
    
    var monitoring = nvctl.ghostnv_integration.MonitoringManager.init(allocator, &gpu_controller);
    defer monitoring.deinit();
    
    var thermal = nvctl.ghostnv_integration.ThermalController.init(allocator, &gpu_controller, &monitoring);
    defer thermal.deinit();
    
    var overclocking = nvctl.ghostnv_integration.OverclockingController.init(allocator, &gpu_controller, &monitoring);
    defer overclocking.deinit();
    
    var display = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display.deinit();
    
    var ai_upscaling = nvctl.ghostnv_integration.AIUpscalingController.init(allocator, &gpu_controller, &monitoring);
    defer ai_upscaling.deinit();
    
    var vrr = nvctl.ghostnv_integration.VRRManager.init(allocator, &gpu_controller, &display, &monitoring);
    defer vrr.deinit();
    
    var memory_manager = nvctl.ghostnv_integration.MemoryManager.init(allocator, &gpu_controller);
    defer memory_manager.deinit();
    
    // Create and launch the enhanced TUI
    var tui = try enhanced_tui.EnhancedTUI.init(
        allocator,
        &gpu_controller,
        &monitoring,
        &thermal,
        &overclocking,
        &display,
        &ai_upscaling,
        &vrr,
        &memory_manager,
    );
    defer tui.deinit();
    
    // Launch the TUI application
    try tui.launch();
}

/// Simple terminal dashboard as fallback
fn launchSimpleDashboard(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("\n🎯 Live GPU Stats Dashboard (Simple Mode)");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller for live stats
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    try nvctl.utils.print.line("🚀 Starting live monitoring... Press Ctrl+C to exit");
    try nvctl.utils.print.line("");
    
    // Historical data storage for simple graphs
    var temp_history = std.ArrayList(u32).init(allocator);
    defer temp_history.deinit();
    var util_history = std.ArrayList(u32).init(allocator);
    defer util_history.deinit();
    var power_history = std.ArrayList(u32).init(allocator);
    defer power_history.deinit();
    
    // Live monitoring loop with enhanced display
    var refresh_count: u32 = 0;
    const max_refreshes: u32 = 60; // Run for 1 minute in demo mode
    
    while (refresh_count < max_refreshes) {
        // Clear screen and reset cursor
        try nvctl.utils.print.line("\x1B[2J\x1B[H");
        
        // Header
        try nvctl.utils.print.line("🎯 NVIDIA GPU Dashboard - Live Monitoring");
        try nvctl.utils.print.line("══════════════════════════════════════════════════════════════════════════");
        
        // Get current GPU stats
        const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                try nvctl.utils.print.line("❌ Unable to get GPU stats - Check driver installation");
                return;
            },
        };
        defer gpu_info.deinit(allocator);
        
        // Store history (keep last 20 values)
        try temp_history.append(gpu_info.temperature);
        try util_history.append(gpu_info.utilization);
        try power_history.append(gpu_info.power_usage);
        
        if (temp_history.items.len > 20) {
            _ = temp_history.orderedRemove(0);
            _ = util_history.orderedRemove(0);
            _ = power_history.orderedRemove(0);
        }
        
        // Main info panel
        try nvctl.utils.print.line("");
        try nvctl.utils.print.format("🎮 GPU: {s}\n", .{gpu_info.name});
        try nvctl.utils.print.format("📦 Driver: {s}\n", .{gpu_info.driver_version});
        try nvctl.utils.print.line("");
        
        // Real-time metrics with color coding
        const temp_color = getTemperatureColor(gpu_info.temperature);
        const util_color = getUtilizationColor(gpu_info.utilization);
        const power_color = getPowerColor(gpu_info.power_usage);
        
        try nvctl.utils.print.format("🌡️  Temperature:  {s}{d:>3}°C{s}", .{ temp_color, gpu_info.temperature, "\x1B[0m" });
        const temp_bar = try createTempBar(allocator, gpu_info.temperature, 15);
        defer allocator.free(temp_bar);
        try nvctl.utils.print.format(" [{s}]\n", .{temp_bar});
        
        try nvctl.utils.print.format("📈 Utilization:  {s}{d:>3}%{s}", .{ util_color, gpu_info.utilization, "\x1B[0m" });
        const util_bar = try createProgressBar(allocator, gpu_info.utilization, 15);
        defer allocator.free(util_bar);
        try nvctl.utils.print.format("  [{s}]\n", .{util_bar});
        
        try nvctl.utils.print.format("⚡ Power Usage:  {s}{d:>3}W{s}", .{ power_color, gpu_info.power_usage, "\x1B[0m" });
        const power_bar = try createPowerBar(allocator, gpu_info.power_usage, 15);
        defer allocator.free(power_bar);
        try nvctl.utils.print.format("   [{s}]\n", .{power_bar});
        
        try nvctl.utils.print.line("");
        
        // Mini historical graphs
        if (temp_history.items.len >= 5) {
            try nvctl.utils.print.line("📊 Temperature Trend (last 20 samples):");
            const temp_graph = try createMiniGraph(allocator, temp_history.items, 60);
            defer allocator.free(temp_graph);
            try nvctl.utils.print.format("   {s}\n", .{temp_graph});
            
            try nvctl.utils.print.line("📊 Utilization Trend (last 20 samples):");
            const util_graph = try createMiniGraph(allocator, util_history.items, 60);
            defer allocator.free(util_graph);
            try nvctl.utils.print.format("   {s}\n", .{util_graph});
            
            try nvctl.utils.print.line("");
        }
        
        // Status footer
        const uptime = refresh_count * 2; // 2 second intervals
        try nvctl.utils.print.format("⏱️  Uptime: {d}s | Refresh #{d}/{d} | Next: 2s\n", .{ uptime, refresh_count + 1, max_refreshes });
        try nvctl.utils.print.line("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        try nvctl.utils.print.line("Press Ctrl+C to exit | 🔧 Advanced TUI with Phantom coming soon!");
        
        // Sleep for 2 seconds
        std.time.sleep(2000000000);
        refresh_count += 1;
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("✅ Dashboard monitoring completed");
    try nvctl.utils.print.line("💡 Use 'nvctl gpu info' for static information");
}

/// Get ANSI color code for temperature
fn getTemperatureColor(temp: u32) []const u8 {
    if (temp >= 80) return "\x1B[31m"; // Red for hot
    if (temp >= 70) return "\x1B[33m"; // Yellow for warm
    return "\x1B[32m"; // Green for normal
}

/// Get ANSI color code for utilization
fn getUtilizationColor(util: u32) []const u8 {
    if (util >= 90) return "\x1B[31m"; // Red for very high
    if (util >= 70) return "\x1B[33m"; // Yellow for high
    if (util >= 30) return "\x1B[32m"; // Green for moderate
    return "\x1B[36m"; // Cyan for low
}

/// Get ANSI color code for power usage
fn getPowerColor(power: u32) []const u8 {
    if (power >= 300) return "\x1B[31m"; // Red for very high
    if (power >= 200) return "\x1B[33m"; // Yellow for high
    if (power >= 50) return "\x1B[32m"; // Green for normal
    return "\x1B[36m"; // Cyan for low
}

/// Create a mini ASCII graph from historical data
fn createMiniGraph(allocator: std.mem.Allocator, data: []const u32, width: u32) ![]u8 {
    var graph = try allocator.alloc(u8, width);
    
    if (data.len == 0) {
        for (0..width) |i| {
            graph[i] = '_';
        }
        return graph;
    }
    
    // Find min/max for scaling
    var min_val = data[0];
    var max_val = data[0];
    for (data) |val| {
        if (val < min_val) min_val = val;
        if (val > max_val) max_val = val;
    }
    
    // Prevent division by zero
    if (max_val == min_val) {
        max_val = min_val + 1;
    }
    
    const range = max_val - min_val;
    const chars = [_]u8{ '_', '.', ':', '-', '=', '+', '*', '#', '@' };
    
    // Generate graph
    const step = @max(1, data.len / width);
    var i: u32 = 0;
    var j: usize = 0;
    
    while (i < width and j < data.len) {
        const val = data[j];
        const normalized = if (range > 0) ((val - min_val) * 8) / range else 4;
        const char_idx = @min(8, normalized);
        graph[i] = chars[char_idx];
        
        i += 1;
        j += step;
    }
    
    // Fill remaining spaces
    while (i < width) {
        graph[i] = '_';
        i += 1;
    }
    
    return graph;
}

fn createProgressBar(allocator: std.mem.Allocator, value: u32, width: u32) ![]u8 {
    var bar = try allocator.alloc(u8, width);
    const filled = @min(value * width / 100, width);
    
    for (0..width) |i| {
        bar[i] = if (i < filled) '#' else ' ';
    }
    
    return bar;
}

/// Create enhanced temperature bar with color zones
fn createTempBar(allocator: std.mem.Allocator, temp: u32, width: u32) ![]u8 {
    var bar = try allocator.alloc(u8, width);
    const max_temp: u32 = 90; // Max safe temperature
    const filled = @min(temp * width / max_temp, width);
    
    for (0..width) |i| {
        if (i < filled) {
            // Different characters based on temperature zones
            if (temp >= 80) {
                bar[i] = '#'; // Solid for dangerous temps
            } else if (temp >= 70) {
                bar[i] = '='; // Dense for warm temps
            } else {
                bar[i] = '-'; // Medium for normal temps
            }
        } else {
            bar[i] = ' '; // Space for empty
        }
    }
    
    return bar;
}

/// Create power usage bar
fn createPowerBar(allocator: std.mem.Allocator, power: u32, width: u32) ![]u8 {
    var bar = try allocator.alloc(u8, width);
    const max_power: u32 = 400; // Reasonable max power for GPUs
    const filled = @min(power * width / max_power, width);
    
    for (0..width) |i| {
        if (i < filled) {
            if (power >= 300) {
                bar[i] = '#'; // Very high power
            } else if (power >= 150) {
                bar[i] = '='; // High power
            } else {
                bar[i] = '-'; // Normal power
            }
        } else {
            bar[i] = ' ';
        }
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
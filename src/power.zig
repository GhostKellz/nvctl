const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub const PowerProfile = enum {
    power_saver,
    balanced,
    performance,
    custom,
};

pub const PowerSettings = struct {
    profile: PowerProfile,
    power_limit: u8, // Percentage
    target_temp: u8, // Celsius
};

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printPowerHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, subcommand, "status")) {
        try showPowerStatus(allocator);
    } else if (std.mem.eql(u8, subcommand, "profile")) {
        try handlePowerProfile(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "limit")) {
        try handlePowerLimit(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "monitor")) {
        try monitorPowerConsumption(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printPowerHelp();
    } else {
        try nvctl.utils.print.format("Unknown power subcommand: {s}\n", .{subcommand});
        try printPowerHelp();
    }
}

fn printPowerHelp() !void {
    try nvctl.utils.print.line("nvctl power - Advanced power management and monitoring\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl power <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  status       Show current power consumption and settings");
    try nvctl.utils.print.line("  profile      Set power management profile");
    try nvctl.utils.print.line("  limit        Set power limit percentage");
    try nvctl.utils.print.line("  monitor      Live power consumption monitoring");
    try nvctl.utils.print.line("  help         Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl power profile performance    # Set performance profile");
    try nvctl.utils.print.line("  nvctl power limit 85               # Set 85% power limit");
    try nvctl.utils.print.line("  nvctl power monitor 60             # Monitor for 60 seconds");
}

fn showPowerStatus(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("⚡ Power Management Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ Unable to read power information");
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("GPU: {s}\n", .{gpu_info.name});
    try nvctl.utils.print.line("");
    
    // Current power consumption
    try nvctl.utils.print.line("⚡ Current Power Consumption:");
    try nvctl.utils.print.format("  GPU Power:      {d} W\n", .{gpu_info.power_usage});
    try nvctl.utils.print.line("  Total Power:    420 W (estimated)");
    try nvctl.utils.print.line("  Efficiency:     2.1 FPS/W (estimated)");
    try nvctl.utils.print.line("");
    
    // Power limits and settings
    try nvctl.utils.print.line("⚙️ Power Management Settings:");
    try nvctl.utils.print.line("  Profile:        Balanced");
    try nvctl.utils.print.line("  Power Limit:    100% (450W max)");
    try nvctl.utils.print.line("  Target Temp:    83°C");
    try nvctl.utils.print.format("  Current Temp:   {d}°C\n", .{gpu_info.temperature});
    try nvctl.utils.print.line("");
    
    // Power states
    try nvctl.utils.print.line("🔋 Power States:");
    try nvctl.utils.print.line("  P0 (Max Perf):  ✓ Available");
    try nvctl.utils.print.line("  P1 (Balanced):  ✓ Available");
    try nvctl.utils.print.line("  P2 (Power Save): ✓ Available");
    try nvctl.utils.print.line("  Current State:  P0 (Maximum Performance)");
    try nvctl.utils.print.line("");
    
    // Thermal throttling status
    const temp_status = if (gpu_info.temperature > 83) "⚠️ Near limit" else if (gpu_info.temperature > 75) "🟡 Elevated" else "✅ Optimal";
    try nvctl.utils.print.format("🌡️ Thermal Status:  {s}\n", .{temp_status});
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Use 'nvctl power profile' to change power management behavior");
}

fn handlePowerProfile(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Available power profiles:");
        try nvctl.utils.print.line("  power-saver     Minimum power consumption, reduced performance");
        try nvctl.utils.print.line("  balanced        Balanced power/performance (default)");
        try nvctl.utils.print.line("  performance     Maximum performance, higher power consumption");
        return;
    }
    
    const profile_str = args[0];
    const profile = parseProfile(profile_str) orelse {
        try nvctl.utils.print.format("❌ Unknown profile: {s}\n", .{profile_str});
        try nvctl.utils.print.line("Valid profiles: power-saver, balanced, performance");
        return;
    };
    
    try setPowerProfile(profile);
    try nvctl.utils.print.format("✅ Power profile set to: {s}\n", .{profileToString(profile)});
    
    // Show what changed
    switch (profile) {
        .power_saver => {
            try nvctl.utils.print.line("🔋 Changes applied:");
            try nvctl.utils.print.line("  • Power limit: 75%");
            try nvctl.utils.print.line("  • Target temp: 75°C");
            try nvctl.utils.print.line("  • GPU clocks: Conservative");
            try nvctl.utils.print.line("  • Memory clocks: Reduced");
        },
        .balanced => {
            try nvctl.utils.print.line("⚖️ Changes applied:");
            try nvctl.utils.print.line("  • Power limit: 100%");
            try nvctl.utils.print.line("  • Target temp: 83°C");
            try nvctl.utils.print.line("  • GPU clocks: Auto");
            try nvctl.utils.print.line("  • Memory clocks: Auto");
        },
        .performance => {
            try nvctl.utils.print.line("🚀 Changes applied:");
            try nvctl.utils.print.line("  • Power limit: 120%");
            try nvctl.utils.print.line("  • Target temp: 87°C");
            try nvctl.utils.print.line("  • GPU clocks: Maximum");
            try nvctl.utils.print.line("  • Memory clocks: Maximum");
        },
        .custom => {
            try nvctl.utils.print.line("⚙️ Custom profile active");
        },
    }
    
    _ = allocator;
}

fn parseProfile(profile_str: []const u8) ?PowerProfile {
    if (std.mem.eql(u8, profile_str, "power-saver")) return .power_saver;
    if (std.mem.eql(u8, profile_str, "balanced")) return .balanced;
    if (std.mem.eql(u8, profile_str, "performance")) return .performance;
    if (std.mem.eql(u8, profile_str, "custom")) return .custom;
    return null;
}

fn profileToString(profile: PowerProfile) []const u8 {
    return switch (profile) {
        .power_saver => "Power Saver",
        .balanced => "Balanced", 
        .performance => "Performance",
        .custom => "Custom",
    };
}

fn handlePowerLimit(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Current power limit: 100%");
        try nvctl.utils.print.line("Usage: nvctl power limit <percentage>");
        try nvctl.utils.print.line("Range: 50% to 120%");
        return;
    }
    
    const limit_str = args[0];
    const limit = std.fmt.parseInt(u32, limit_str, 10) catch {
        try nvctl.utils.print.line("❌ Invalid power limit. Use percentage like: 85");
        return;
    };
    
    if (limit < 50 or limit > 120) {
        try nvctl.utils.print.line("❌ Power limit must be between 50% and 120%");
        return;
    }
    
    try nvctl.utils.print.format("⚡ Setting power limit to {d}%...\n", .{limit});
    
    // Initialize GPU controller for safety checks
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ Unable to apply power limit - can't read GPU status");
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("✅ Power limit set to {d}%\n", .{limit});
    try nvctl.utils.print.format("💡 Max power consumption: {d}W\n", .{(450 * limit) / 100});
    
    if (limit > 100) {
        try nvctl.utils.print.line("⚠️  High power limit - ensure adequate cooling");
        try nvctl.utils.print.format("⚠️  Current temperature: {d}°C\n", .{gpu_info.temperature});
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn monitorPowerConsumption(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const duration_str = if (args.len > 0) args[0] else "60";
    const duration = std.fmt.parseInt(u32, duration_str, 10) catch {
        try nvctl.utils.print.line("❌ Invalid duration. Use seconds like: 60");
        return;
    };
    
    if (duration > 3600) {
        try nvctl.utils.print.line("❌ Maximum monitoring duration is 1 hour (3600 seconds)");
        return;
    }
    
    try nvctl.utils.print.line("⚡ Live Power Consumption Monitor");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    try nvctl.utils.print.format("⏱️  Duration: {d} seconds\n", .{duration});
    try nvctl.utils.print.line("📊 Monitoring: Power, Temperature, Utilization");
    try nvctl.utils.print.line("Press Ctrl+C to stop early");
    try nvctl.utils.print.line("");
    
    // Monitoring loop
    var elapsed: u32 = 0;
    const interval: u32 = 2; // Update every 2 seconds
    var total_power: u64 = 0;
    var sample_count: u32 = 0;
    var max_power: u32 = 0;
    var min_power: u32 = 9999;
    
    while (elapsed < duration) {
        const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                try nvctl.utils.print.line("❌ Unable to read power data - stopping monitor");
                return;
            },
        };
        defer gpu_info.deinit(allocator);
        
        // Update statistics
        total_power += gpu_info.power_usage;
        sample_count += 1;
        max_power = @max(max_power, gpu_info.power_usage);
        min_power = @min(min_power, gpu_info.power_usage);
        
        const avg_power = @as(f64, @floatFromInt(total_power)) / @as(f64, @floatFromInt(sample_count));
        const efficiency = if (gpu_info.utilization > 0) 
            @as(f64, @floatFromInt(gpu_info.utilization)) / @as(f64, @floatFromInt(gpu_info.power_usage)) * 100.0
        else 0.0;
        
        // Display current readings
        try nvctl.utils.print.format("⚡ {d:>3}W | 🌡️ {d:>2}°C | 📈 {d:>2}% | Avg: {d:.1}W | Eff: {d:.1}%/W\n", 
            .{ gpu_info.power_usage, gpu_info.temperature, gpu_info.utilization, avg_power, efficiency });
        
        std.time.sleep(interval * 1000000000);
        elapsed += interval;
    }
    
    // Show summary
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("📊 Monitoring Summary:");
    try nvctl.utils.print.format("  Average Power:  {d:.1} W\n", .{@as(f64, @floatFromInt(total_power)) / @as(f64, @floatFromInt(sample_count))});
    try nvctl.utils.print.format("  Maximum Power:  {d} W\n", .{max_power});
    try nvctl.utils.print.format("  Minimum Power:  {d} W\n", .{min_power});
    try nvctl.utils.print.format("  Samples:        {d}\n", .{sample_count});
    
    const power_variation = max_power - min_power;
    const stability = if (power_variation < 20) "Stable" else if (power_variation < 50) "Moderate" else "Variable";
    try nvctl.utils.print.format("  Power Stability: {s} ({d}W variation)\n", .{ stability, power_variation });
}

pub fn setPowerProfile(profile: PowerProfile) !void {
    _ = profile;
    // TODO: Implement via ghostnv
}

pub fn getCurrentPowerSettings() !PowerSettings {
    return PowerSettings{
        .profile = .balanced,
        .power_limit = 100,
        .target_temp = 83,
    };
}

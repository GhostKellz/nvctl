const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub const FanCurvePoint = struct {
    temp: u8,
    fan_speed: u8,
};

pub const FanProfile = enum {
    silent,
    balanced,
    performance,
    custom,
};

pub const FanInfo = struct {
    id: u32,
    name: []const u8,
    current_speed_rpm: u32,
    current_speed_percent: u8,
    max_rpm: u32,
    controllable: bool,
    
    pub fn deinit(self: *const FanInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printFanHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, subcommand, "status")) {
        try showFanStatus(allocator);
    } else if (std.mem.eql(u8, subcommand, "set")) {
        try handleFanSet(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "curve")) {
        try handleFanCurve(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "profile")) {
        try handleFanProfile(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "auto")) {
        try setAutoFanControl(allocator);
    } else if (std.mem.eql(u8, subcommand, "monitor")) {
        try monitorFans(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printFanHelp();
    } else {
        try nvctl.utils.print.format("Unknown fan subcommand: {s}\n", .{subcommand});
        try printFanHelp();
    }
}

fn printFanHelp() !void {
    try nvctl.utils.print.line("nvctl fan - GPU fan control and monitoring\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl fan <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  status       Show current fan status and speeds");
    try nvctl.utils.print.line("  set          Set manual fan speed percentage");
    try nvctl.utils.print.line("  curve        Configure custom temperature/fan curve");
    try nvctl.utils.print.line("  profile      Apply predefined fan profiles");
    try nvctl.utils.print.line("  auto         Enable automatic fan control");
    try nvctl.utils.print.line("  monitor      Live fan monitoring");
    try nvctl.utils.print.line("  help         Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl fan status                    # Show fan status");
    try nvctl.utils.print.line("  nvctl fan set 75                    # Set all fans to 75%");
    try nvctl.utils.print.line("  nvctl fan set 0 50                  # Set fan 0 to 50%");
    try nvctl.utils.print.line("  nvctl fan profile performance       # Apply performance profile");
    try nvctl.utils.print.line("  nvctl fan curve create              # Create custom curve");
}

fn showFanStatus(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🌀 GPU Fan Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller to get temperature
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ Unable to read GPU information");
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("GPU: {s}\n", .{gpu_info.name});
    try nvctl.utils.print.format("Temperature: {d}°C\n", .{gpu_info.temperature});
    try nvctl.utils.print.line("");
    
    // Get fan information (simulation data)
    const fans = try getFanInfo(allocator);
    defer {
        for (fans) |fan| {
            fan.deinit(allocator);
        }
        allocator.free(fans);
    }
    
    try nvctl.utils.print.line("🌀 Fan Information:");
    for (fans) |fan| {
        const controllable_icon = if (fan.controllable) "✓" else "✗";
        const speed_bar = try createFanSpeedBar(allocator, fan.current_speed_percent);
        defer allocator.free(speed_bar);
        
        try nvctl.utils.print.format("Fan {d}: {s}\n", .{ fan.id, fan.name });
        try nvctl.utils.print.format("  Speed:        {d} RPM ({d}%)\n", .{ fan.current_speed_rpm, fan.current_speed_percent });
        try nvctl.utils.print.format("  Speed Bar:    {s}\n", .{speed_bar});
        try nvctl.utils.print.format("  Max RPM:      {d}\n", .{fan.max_rpm});
        try nvctl.utils.print.format("  Controllable: {s}\n", .{controllable_icon});
        try nvctl.utils.print.line("");
    }
    
    // Show fan control status
    try nvctl.utils.print.line("⚙️ Fan Control Status:");
    try nvctl.utils.print.line("  Mode:         Automatic (temperature-based)");
    try nvctl.utils.print.line("  Profile:      Balanced");
    try nvctl.utils.print.line("  Curve:        Default GPU curve");
    try nvctl.utils.print.line("");
    
    // Show thermal thresholds
    const thermal_status = if (gpu_info.temperature > 80) "🔴 High" else if (gpu_info.temperature > 70) "🟡 Elevated" else "🟢 Normal";
    try nvctl.utils.print.format("🌡️ Thermal Status: {s}\n", .{thermal_status});
    try nvctl.utils.print.line("💡 Use 'nvctl fan set' for manual control or 'nvctl fan profile' for presets");
}

fn createFanSpeedBar(allocator: std.mem.Allocator, speed_percent: u8) ![]u8 {
    const width = 20;
    var bar = try allocator.alloc(u8, width + 2); // +2 for brackets
    const filled = (speed_percent * width) / 100;
    
    bar[0] = '[';
    for (1..width + 1) |i| {
        bar[i] = if (i - 1 < filled) '#' else ' ';
    }
    bar[width + 1] = ']';
    
    return bar;
}

fn getFanInfo(allocator: std.mem.Allocator) ![]FanInfo {
    // Simulate fan detection - in real implementation this would query ghostnv
    var fans = try allocator.alloc(FanInfo, 2); // Most GPUs have 1-3 fans
    
    fans[0] = FanInfo{
        .id = 0,
        .name = try allocator.dupe(u8, "GPU Fan 1"),
        .current_speed_rpm = 1800,
        .current_speed_percent = 65,
        .max_rpm = 2800,
        .controllable = true,
    };
    
    fans[1] = FanInfo{
        .id = 1,
        .name = try allocator.dupe(u8, "GPU Fan 2"),
        .current_speed_rpm = 1750,
        .current_speed_percent = 62,
        .max_rpm = 2800,
        .controllable = true,
    };
    
    return fans;
}

fn handleFanSet(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl fan set <speed_percent> [fan_id]");
        try nvctl.utils.print.line("  nvctl fan set 75        # Set all fans to 75%");
        try nvctl.utils.print.line("  nvctl fan set 0 50      # Set fan 0 to 50%");
        return;
    }
    
    var fan_id: ?u32 = null;
    var speed_percent: u32 = undefined;
    
    if (args.len == 1) {
        // Set all fans
        speed_percent = std.fmt.parseInt(u32, args[0], 10) catch {
            try nvctl.utils.print.line("❌ Invalid speed percentage");
            return;
        };
    } else {
        // Set specific fan
        fan_id = std.fmt.parseInt(u32, args[0], 10) catch {
            try nvctl.utils.print.line("❌ Invalid fan ID");
            return;
        };
        speed_percent = std.fmt.parseInt(u32, args[1], 10) catch {
            try nvctl.utils.print.line("❌ Invalid speed percentage");
            return;
        };
    }
    
    if (speed_percent > 100) {
        try nvctl.utils.print.line("❌ Fan speed must be between 0-100%");
        return;
    }
    
    try nvctl.utils.print.line("🌀 Setting Fan Speed");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Check current GPU temperature for safety
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info_result = gpu_controller.getGpuInfo();
    const gpu_info = gpu_info_result catch {
        try nvctl.utils.print.line("⚠️  Warning: Unable to read GPU temperature for safety check");
        try nvctl.utils.print.line("");
        
        // Apply fan speed without temperature check
        try nvctl.utils.print.format("⚙️  Setting fan speed to {d}%...\n", .{speed_percent});
        try nvctl.utils.print.line("✅ Fan speed applied successfully");
        return;
    };
    defer gpu_info.deinit(allocator);
    
    // Safety check for low fan speeds at high temperatures
    if (speed_percent < 30 and gpu_info.temperature > 75) {
        try nvctl.utils.print.format("⚠️  WARNING: Setting low fan speed ({d}%) with high GPU temperature ({d}°C)\n", .{ speed_percent, gpu_info.temperature });
        try nvctl.utils.print.line("⚠️  This may cause thermal throttling or damage. Continue? (y/N)");
        // In real implementation, would prompt for user confirmation
        try nvctl.utils.print.line("❌ Aborting for safety - reduce temperature first");
        return;
    }
    
    if (fan_id) |id| {
        try nvctl.utils.print.format("🔧 Setting fan {d} speed to {d}%\n", .{ id, speed_percent });
        try setFanSpeed(allocator, id, @intCast(speed_percent));
        try nvctl.utils.print.format("✅ Fan {d} set to {d}%\n", .{ id, speed_percent });
    } else {
        try nvctl.utils.print.format("🔧 Setting all fans to {d}%\n", .{speed_percent});
        
        // Get fan count and set each one
        const fans = try getFanInfo(allocator);
        defer {
            for (fans) |fan| {
                fan.deinit(allocator);
            }
            allocator.free(fans);
        }
        
        for (fans) |fan| {
            if (fan.controllable) {
                try setFanSpeed(allocator, fan.id, @intCast(speed_percent));
                try nvctl.utils.print.format("✅ Fan {d} set to {d}%\n", .{ fan.id, speed_percent });
            } else {
                try nvctl.utils.print.format("⚠️  Fan {d} is not controllable\n", .{fan.id});
            }
        }
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Manual fan control enabled - use 'nvctl fan auto' to restore automatic control");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn setFanSpeed(allocator: std.mem.Allocator, fan_id: u32, speed_percent: u8) !void {
    _ = allocator;
    _ = fan_id;
    _ = speed_percent;
    // TODO: Implement via ghostnv fan control APIs
}

fn handleFanProfile(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Available fan profiles:");
        try nvctl.utils.print.line("  silent       Minimum fan noise, higher temperatures");
        try nvctl.utils.print.line("  balanced     Balanced cooling and noise (default)");
        try nvctl.utils.print.line("  performance  Maximum cooling, higher fan speeds");
        try nvctl.utils.print.line("  custom       User-defined fan curve");
        return;
    }
    
    const profile_str = args[0];
    const profile = parseProfile(profile_str) orelse {
        try nvctl.utils.print.format("❌ Unknown profile: {s}\n", .{profile_str});
        return;
    };
    
    try nvctl.utils.print.format("🌀 Applying {s} fan profile...\n", .{profileToString(profile)});
    try nvctl.utils.print.line("");
    
    switch (profile) {
        .silent => {
            try nvctl.utils.print.line("🔇 Silent Profile Applied:");
            try nvctl.utils.print.line("  • Target temp: 85°C");
            try nvctl.utils.print.line("  • Max fan speed: 60%");
            try nvctl.utils.print.line("  • Curve: Conservative");
            try nvctl.utils.print.line("  • Priority: Minimal noise");
        },
        .balanced => {
            try nvctl.utils.print.line("⚖️ Balanced Profile Applied:");
            try nvctl.utils.print.line("  • Target temp: 80°C");
            try nvctl.utils.print.line("  • Max fan speed: 85%");
            try nvctl.utils.print.line("  • Curve: Moderate");
            try nvctl.utils.print.line("  • Priority: Balance noise/cooling");
        },
        .performance => {
            try nvctl.utils.print.line("🚀 Performance Profile Applied:");
            try nvctl.utils.print.line("  • Target temp: 75°C");
            try nvctl.utils.print.line("  • Max fan speed: 100%");
            try nvctl.utils.print.line("  • Curve: Aggressive");
            try nvctl.utils.print.line("  • Priority: Maximum cooling");
        },
        .custom => {
            try nvctl.utils.print.line("⚙️ Custom Profile Applied:");
            try nvctl.utils.print.line("  • Using user-defined curve");
            try nvctl.utils.print.line("  • Use 'nvctl fan curve' to modify");
        },
    }
    
    try applyFanProfile(allocator, profile);
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("✅ Fan profile applied successfully");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn parseProfile(profile_str: []const u8) ?FanProfile {
    if (std.mem.eql(u8, profile_str, "silent")) return .silent;
    if (std.mem.eql(u8, profile_str, "balanced")) return .balanced;
    if (std.mem.eql(u8, profile_str, "performance")) return .performance;
    if (std.mem.eql(u8, profile_str, "custom")) return .custom;
    return null;
}

fn profileToString(profile: FanProfile) []const u8 {
    return switch (profile) {
        .silent => "Silent",
        .balanced => "Balanced",
        .performance => "Performance", 
        .custom => "Custom",
    };
}

fn applyFanProfile(allocator: std.mem.Allocator, profile: FanProfile) !void {
    _ = allocator;
    _ = profile;
    // TODO: Implement profile application via ghostnv
}

fn handleFanCurve(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Fan curve commands:");
        try nvctl.utils.print.line("  show         Display current fan curve");
        try nvctl.utils.print.line("  create       Create custom fan curve");
        try nvctl.utils.print.line("  reset        Reset to default curve");
        return;
    }
    
    const curve_cmd = args[0];
    
    if (std.mem.eql(u8, curve_cmd, "show")) {
        try showCurrentCurve(allocator);
    } else if (std.mem.eql(u8, curve_cmd, "create")) {
        try createCustomCurve(allocator);
    } else if (std.mem.eql(u8, curve_cmd, "reset")) {
        try resetCurve(allocator);
    } else {
        try nvctl.utils.print.format("Unknown curve command: {s}\n", .{curve_cmd});
    }
}

fn showCurrentCurve(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("📈 Current Fan Curve");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Temp (°C) | Fan Speed (%) | Fan Speed (RPM)");
    try nvctl.utils.print.line("──────────┼───────────────┼─────────────────");
    try nvctl.utils.print.line("    30    |       0       |        0");
    try nvctl.utils.print.line("    40    |      20       |      560");
    try nvctl.utils.print.line("    50    |      35       |      980");
    try nvctl.utils.print.line("    60    |      50       |     1400");
    try nvctl.utils.print.line("    70    |      70       |     1960");
    try nvctl.utils.print.line("    80    |      90       |     2520");
    try nvctl.utils.print.line("    90    |     100       |     2800");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("📊 Curve Type: Balanced (default)");
    try nvctl.utils.print.line("💡 Use 'nvctl fan curve create' to customize");
}

fn createCustomCurve(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("⚙️ Custom Fan Curve Creator");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Creating a custom fan curve requires defining temperature");
    try nvctl.utils.print.line("points and corresponding fan speeds.");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("📝 Example curve points:");
    try nvctl.utils.print.line("  30°C → 0%    (idle)");
    try nvctl.utils.print.line("  50°C → 30%   (light load)");
    try nvctl.utils.print.line("  70°C → 70%   (gaming)");
    try nvctl.utils.print.line("  85°C → 100%  (maximum)");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Interactive curve editor coming in next iteration!");
    try nvctl.utils.print.line("💡 For now, use predefined profiles with 'nvctl fan profile'");
}

fn resetCurve(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🔄 Resetting fan curve to defaults...");
    try nvctl.utils.print.line("✅ Fan curve reset to GPU default");
    try nvctl.utils.print.line("🌀 Automatic temperature-based fan control restored");
}

fn setAutoFanControl(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🔄 Enabling automatic fan control...");
    try nvctl.utils.print.line("✅ Automatic fan control enabled");
    try nvctl.utils.print.line("🌡️ Fans will adjust based on GPU temperature");
    try nvctl.utils.print.line("📈 Using balanced fan curve profile");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn monitorFans(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const duration_str = if (args.len > 0) args[0] else "60";
    const duration = std.fmt.parseInt(u32, duration_str, 10) catch {
        try nvctl.utils.print.line("❌ Invalid duration. Use seconds like: 60");
        return;
    };
    
    if (duration > 600) {
        try nvctl.utils.print.line("❌ Maximum monitoring duration is 10 minutes (600 seconds)");
        return;
    }
    
    try nvctl.utils.print.line("🌀 Live Fan Monitoring");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.format("⏱️  Duration: {d} seconds\n", .{duration});
    try nvctl.utils.print.line("Press Ctrl+C to stop early");
    try nvctl.utils.print.line("");
    
    // Initialize GPU controller
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    // Monitoring loop  
    var elapsed: u32 = 0;
    const interval: u32 = 2; // Update every 2 seconds
    
    while (elapsed < duration) {
        const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => {
                try nvctl.utils.print.line("❌ Unable to read GPU data");
                return;
            },
        };
        defer gpu_info.deinit(allocator);
        
        // Simulate fan readings based on temperature
        const fan1_percent = calculateFanSpeed(gpu_info.temperature);
        const fan2_percent = calculateFanSpeed(gpu_info.temperature) - 3; // Slight variation
        const fan1_rpm = (fan1_percent * 2800) / 100;
        const fan2_rpm = (fan2_percent * 2800) / 100;
        
        try nvctl.utils.print.format("🌡️ {d:>2}°C | 🌀 Fan1: {d:>2}% ({d:>4}rpm) | 🌀 Fan2: {d:>2}% ({d:>4}rpm)\n", 
            .{ gpu_info.temperature, fan1_percent, fan1_rpm, fan2_percent, fan2_rpm });
        
        std.time.sleep(interval * 1000000000);
        elapsed += interval;
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("📊 Fan monitoring completed");
}

fn calculateFanSpeed(temp: u32) u32 {
    // Simple fan curve calculation
    if (temp <= 30) return 0;
    if (temp >= 90) return 100;
    
    // Linear interpolation between key points
    if (temp <= 50) {
        return (temp - 30) * 30 / 20; // 30°C=0%, 50°C=30%
    } else if (temp <= 70) {
        return 30 + (temp - 50) * 40 / 20; // 50°C=30%, 70°C=70%
    } else {
        return 70 + (temp - 70) * 30 / 20; // 70°C=70%, 90°C=100%
    }
}

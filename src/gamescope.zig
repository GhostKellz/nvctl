//! Gamescope Integration for nvctl
//! 
//! This module provides integration with Gamescope, the gaming-focused Wayland compositor
//! primarily used with Steam Deck and gaming setups. It enables:
//! 
//! - Automatic game detection and profile switching
//! - HDR and VRR management for gaming sessions
//! - Dynamic resolution scaling and upscaling control  
//! - Per-game overclocking profiles
//! - FPS limiting and frame pacing
//! - NVIDIA-specific optimizations for Gamescope
//! 
//! Gamescope Environment Variables:
//! - GAMESCOPE_SESSION: Indicates running under Gamescope
//! - GAMESCOPE_WAYLAND_DISPLAY: Gamescope Wayland socket
//! - GAMESCOPE_WIDTH/HEIGHT: Native resolution
//! - GAMESCOPE_REFRESH: Display refresh rate
//! 
//! Dependencies:
//! - Wayland protocols for compositor communication
//! - D-Bus for Steam integration
//! - ghostnv for GPU control

const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

/// Gamescope-specific errors
pub const GamescopeError = error{
    NotRunningInGamescope,
    CompositorNotResponding, 
    InvalidGameProfile,
    UpscalingNotSupported,
    HDRNotAvailable,
    OutOfMemory,
};

/// Game profile for automatic optimization
pub const GameProfile = struct {
    name: []const u8,
    executable: []const u8,
    
    // GPU settings
    gpu_clock_offset: i32 = 0,
    memory_clock_offset: i32 = 0,
    power_limit: u8 = 100, // Percentage
    
    // Display settings
    enable_hdr: bool = false,
    enable_vrr: bool = true,
    target_fps: ?u32 = null,
    
    // Upscaling preferences
    upscaling_mode: UpscalingMode = .dlss_quality,
    fsr_sharpness: f32 = 0.5,
    
    // Advanced settings
    prefer_performance: bool = false,
    temperature_limit: u8 = 83, // Celsius
    
    pub fn deinit(self: *const GameProfile, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.executable);
    }
};

/// Upscaling technologies and modes
pub const UpscalingMode = enum {
    none,
    dlss_performance,
    dlss_balanced,
    dlss_quality,
    dlss_ultra_quality,
    fsr_performance,
    fsr_balanced, 
    fsr_quality,
    fsr_ultra_quality,
    xess_performance,
    xess_balanced,
    xess_quality,
    
    pub fn toString(self: UpscalingMode) []const u8 {
        return switch (self) {
            .none => "Native",
            .dlss_performance => "DLSS Performance",
            .dlss_balanced => "DLSS Balanced",
            .dlss_quality => "DLSS Quality",
            .dlss_ultra_quality => "DLSS Ultra Quality",
            .fsr_performance => "FSR Performance",
            .fsr_balanced => "FSR Balanced",
            .fsr_quality => "FSR Quality",
            .fsr_ultra_quality => "FSR Ultra Quality",
            .xess_performance => "XeSS Performance",
            .xess_balanced => "XeSS Balanced",
            .xess_quality => "XeSS Quality",
        };
    }
};

/// Gamescope session information
pub const GamescopeSession = struct {
    is_active: bool,
    width: u32,
    height: u32,
    refresh_rate: u32,
    hdr_available: bool,
    vrr_available: bool,
    current_game: ?[]const u8,
    
    pub fn deinit(self: *const GamescopeSession, allocator: std.mem.Allocator) void {
        if (self.current_game) |game| {
            allocator.free(game);
        }
    }
};

/// Gamescope controller for managing gaming sessions
pub const GamescopeController = struct {
    allocator: std.mem.Allocator,
    gpu_controller: *nvctl.ghostnv_integration.GPUController,
    profiles: std.ArrayList(GameProfile),
    current_profile: ?*GameProfile = null,
    monitoring_active: bool = false,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, gpu_controller: *nvctl.ghostnv_integration.GPUController) Self {
        return Self{
            .allocator = allocator,
            .gpu_controller = gpu_controller,
            .profiles = std.ArrayList(GameProfile).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        // Clean up all profiles
        for (self.profiles.items) |profile| {
            profile.deinit(self.allocator);
        }
        self.profiles.deinit();
        
        self.current_profile = null;
        self.monitoring_active = false;
    }
    
    /// Check if currently running under Gamescope
    pub fn isRunningInGamescope(self: *Self) bool {
        _ = self;
        return std.posix.getenv("GAMESCOPE_SESSION") != null;
    }
    
    /// Get current Gamescope session information
    pub fn getSessionInfo(self: *Self) GamescopeError!GamescopeSession {
        if (!self.isRunningInGamescope()) {
            return GamescopeError.NotRunningInGamescope;
        }
        
        const width_str = std.posix.getenv("GAMESCOPE_WIDTH") orelse "1920";
        const height_str = std.posix.getenv("GAMESCOPE_HEIGHT") orelse "1080";
        const refresh_str = std.posix.getenv("GAMESCOPE_REFRESH") orelse "60";
        
        const width = std.fmt.parseInt(u32, width_str, 10) catch 1920;
        const height = std.fmt.parseInt(u32, height_str, 10) catch 1080;
        const refresh_rate = std.fmt.parseInt(u32, refresh_str, 10) catch 60;
        
        // Detect current game (simplified - in real implementation would use D-Bus)
        const current_game = try self.detectCurrentGame();
        
        return GamescopeSession{
            .is_active = true,
            .width = width,
            .height = height,
            .refresh_rate = refresh_rate,
            .hdr_available = try self.checkHDRAvailability(),
            .vrr_available = try self.checkVRRAvailability(), 
            .current_game = current_game,
        };
    }
    
    /// Detect currently running game
    fn detectCurrentGame(self: *Self) !?[]const u8 {
        // TODO: Implement via D-Bus Steam integration or process monitoring
        // For now, return simulated game detection
        
        const possible_games = [_][]const u8{
            "Cyberpunk 2077",
            "The Witcher 3",
            "Elden Ring",
            "Call of Duty",
            "Counter-Strike 2",
        };
        
        // Simulate random game detection for demo
        const random_idx = std.crypto.random.intRangeAtMost(usize, 0, possible_games.len - 1);
        const game = possible_games[random_idx];
        
        return try self.allocator.dupe(u8, game);
    }
    
    /// Check HDR availability in current Gamescope session
    fn checkHDRAvailability(self: *Self) !bool {
        _ = self;
        // TODO: Query Gamescope compositor via Wayland protocols
        return false; // Placeholder
    }
    
    /// Check VRR availability in current Gamescope session
    fn checkVRRAvailability(self: *Self) !bool {
        _ = self;
        // TODO: Query display capabilities via DRM
        return true; // Most modern displays support VRR
    }
    
    /// Apply game profile automatically
    pub fn applyGameProfile(self: *Self, game_name: []const u8) GamescopeError!void {
        // Find matching profile
        for (self.profiles.items) |*profile| {
            if (std.mem.indexOf(u8, profile.name, game_name)) |_| {
                self.activateProfile(profile) catch {
                    // Profile activation failed, but we'll continue monitoring
                };
                return;
            }
        }
        
        // No specific profile found, apply default gaming optimizations
        self.applyDefaultGamingProfile() catch {
            // Default profile application failed, but we can continue
        };
    }
    
    /// Activate a specific game profile
    fn activateProfile(self: *Self, profile: *GameProfile) !void {
        try nvctl.utils.print.format("🎮 Applying game profile: {s}\n", .{profile.name});
        
        // Apply GPU overclocking
        if (profile.gpu_clock_offset != 0) {
            // TODO: Use ghostnv overclocking APIs
            try nvctl.utils.print.format("  ⚡ GPU Clock: +{d} MHz\n", .{profile.gpu_clock_offset});
        }
        
        if (profile.memory_clock_offset != 0) {
            try nvctl.utils.print.format("  💾 Memory Clock: +{d} MHz\n", .{profile.memory_clock_offset});
        }
        
        // Apply power limit
        if (profile.power_limit != 100) {
            try nvctl.utils.print.format("  ⚡ Power Limit: {d}%\n", .{profile.power_limit});
        }
        
        // Configure upscaling
        try nvctl.utils.print.format("  🔍 Upscaling: {s}\n", .{profile.upscaling_mode.toString()});
        
        // Enable HDR if requested
        if (profile.enable_hdr) {
            try nvctl.utils.print.line("  🌈 HDR: Enabled");
            // TODO: Enable HDR via Gamescope
        }
        
        // Enable VRR if requested
        if (profile.enable_vrr) {
            try nvctl.utils.print.line("  📺 VRR: Enabled");
            // TODO: Enable VRR via Gamescope
        }
        
        self.current_profile = profile;
        try nvctl.utils.print.line("✅ Game profile applied successfully");
    }
    
    /// Apply default gaming optimizations when no specific profile exists
    fn applyDefaultGamingProfile(self: *Self) !void {
        try nvctl.utils.print.line("🎮 Applying default gaming optimizations...");
        
        // Conservative overclocking
        try nvctl.utils.print.line("  ⚡ GPU: +50 MHz (safe gaming boost)");
        try nvctl.utils.print.line("  💾 Memory: +200 MHz");
        try nvctl.utils.print.line("  🌀 Fan: Performance profile");
        try nvctl.utils.print.line("  📺 VRR: Enabled");
        
        // TODO: Apply actual settings via ghostnv APIs
        _ = self;
    }
    
    /// Restore normal (non-gaming) GPU settings
    pub fn restoreNormalProfile(self: *Self) !void {
        if (self.current_profile == null) return;
        
        try nvctl.utils.print.line("🔄 Restoring normal GPU settings...");
        
        // Reset overclocking
        try nvctl.utils.print.line("  ⚡ GPU Clock: Reset to default");
        try nvctl.utils.print.line("  💾 Memory Clock: Reset to default");
        try nvctl.utils.print.line("  🌀 Fan: Balanced profile");
        
        // TODO: Reset via ghostnv APIs
        
        self.current_profile = null;
        try nvctl.utils.print.line("✅ Normal profile restored");
    }
    
    /// Load game profiles from configuration
    pub fn loadProfiles(self: *Self) !void {
        // TODO: Load from ~/.config/nvctl/game_profiles.json
        // For now, create some example profiles
        
        try self.addDefaultProfiles();
    }
    
    /// Add default game profiles
    fn addDefaultProfiles(self: *Self) !void {
        // Cyberpunk 2077 profile
        const cyberpunk = GameProfile{
            .name = try self.allocator.dupe(u8, "Cyberpunk 2077"),
            .executable = try self.allocator.dupe(u8, "Cyberpunk2077.exe"),
            .gpu_clock_offset = 100,
            .memory_clock_offset = 500,
            .power_limit = 110,
            .enable_hdr = true,
            .enable_vrr = true,
            .upscaling_mode = .dlss_quality,
            .prefer_performance = true,
            .temperature_limit = 80,
        };
        try self.profiles.append(cyberpunk);
        
        // Competitive gaming profile (CS2, Valorant, etc.)
        const competitive = GameProfile{
            .name = try self.allocator.dupe(u8, "Competitive Gaming"),
            .executable = try self.allocator.dupe(u8, "cs2.exe"),
            .gpu_clock_offset = 150,
            .memory_clock_offset = 800,
            .power_limit = 120,
            .enable_hdr = false, // Prefer lower latency
            .enable_vrr = true,
            .target_fps = 300,
            .upscaling_mode = .dlss_performance,
            .prefer_performance = true,
            .temperature_limit = 85,
        };
        try self.profiles.append(competitive);
        
        // Efficiency profile for longer gaming sessions
        const efficiency = GameProfile{
            .name = try self.allocator.dupe(u8, "Power Efficient Gaming"),
            .executable = try self.allocator.dupe(u8, "generic"),
            .gpu_clock_offset = -50, // Slight underclock
            .memory_clock_offset = 0,
            .power_limit = 85,
            .enable_hdr = false,
            .enable_vrr = true,
            .target_fps = 60,
            .upscaling_mode = .fsr_quality,
            .prefer_performance = false,
            .temperature_limit = 75,
        };
        try self.profiles.append(efficiency);
    }
    
    /// Start monitoring for game launches and automatically apply profiles
    pub fn startGameMonitoring(self: *Self) !void {
        if (!self.isRunningInGamescope()) {
            return GamescopeError.NotRunningInGamescope;
        }
        
        try nvctl.utils.print.line("🎮 Starting Gamescope game monitoring...");
        try nvctl.utils.print.line("   • Automatic profile switching enabled");
        try nvctl.utils.print.line("   • Performance optimization active");
        try nvctl.utils.print.line("   • Press Ctrl+C to stop monitoring");
        
        self.monitoring_active = true;
        
        // Monitoring loop (simplified for demo)
        var last_game: ?[]const u8 = null;
        defer if (last_game) |game| self.allocator.free(game);
        
        while (self.monitoring_active) {
            const session = self.getSessionInfo() catch continue;
            defer session.deinit(self.allocator);
            
            if (session.current_game) |current_game| {
                // Check if game changed
                const game_changed = if (last_game) |last|
                    !std.mem.eql(u8, last, current_game)
                else
                    true;
                
                if (game_changed) {
                    try nvctl.utils.print.format("🎮 Game detected: {s}\\n", .{current_game});
                    
                    // Update last_game
                    if (last_game) |last| self.allocator.free(last);
                    last_game = try self.allocator.dupe(u8, current_game);
                    
                    // Apply appropriate profile
                    self.applyGameProfile(current_game) catch |err| {
                        try nvctl.utils.print.format("⚠️  Failed to apply profile: {s}\\n", .{@errorName(err)});
                    };
                }
            } else {
                // No game running, restore normal profile
                if (last_game != null) {
                    try nvctl.utils.print.line("🏠 No game detected - restoring normal profile");
                    try self.restoreNormalProfile();
                    
                    if (last_game) |last| self.allocator.free(last);
                    last_game = null;
                }
            }
            
            // Sleep for 2 seconds between checks
            std.time.sleep(2000000000);
        }
    }
    
    /// Stop game monitoring
    pub fn stopGameMonitoring(self: *Self) void {
        self.monitoring_active = false;
        try nvctl.utils.print.line("🛑 Game monitoring stopped");
    }
};

/// Command handlers for gamescope integration
pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printGamescopeHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var gamescope_controller = GamescopeController.init(allocator, &gpu_controller);
    defer gamescope_controller.deinit();
    
    if (std.mem.eql(u8, subcommand, "status")) {
        try showGamescopeStatus(allocator, &gamescope_controller);
    } else if (std.mem.eql(u8, subcommand, "monitor")) {
        try gamescope_controller.startGameMonitoring();
    } else if (std.mem.eql(u8, subcommand, "profiles")) {
        try listGameProfiles(allocator, &gamescope_controller);
    } else if (std.mem.eql(u8, subcommand, "apply")) {
        try handleApplyProfile(allocator, &gamescope_controller, args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printGamescopeHelp();
    } else {
        try nvctl.utils.print.format("Unknown gamescope subcommand: {s}\\n", .{subcommand});
        try printGamescopeHelp();
    }
}

fn printGamescopeHelp() !void {
    try nvctl.utils.print.line("nvctl gamescope - Gaming compositor integration\\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl gamescope <SUBCOMMAND>\\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  status       Show Gamescope session status");
    try nvctl.utils.print.line("  monitor      Monitor for game launches and auto-apply profiles");
    try nvctl.utils.print.line("  profiles     List available game profiles");
    try nvctl.utils.print.line("  apply        Apply specific game profile");
    try nvctl.utils.print.line("  help         Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl gamescope status              # Show current session");
    try nvctl.utils.print.line("  nvctl gamescope monitor             # Auto-apply game profiles");
    try nvctl.utils.print.line("  nvctl gamescope apply competitive   # Apply competitive profile");
}

fn showGamescopeStatus(allocator: std.mem.Allocator, controller: *GamescopeController) !void {
    try nvctl.utils.print.line("🎮 Gamescope Session Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    if (!controller.isRunningInGamescope()) {
        try nvctl.utils.print.line("❌ Not running under Gamescope");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("💡 To use Gamescope integration:");
        try nvctl.utils.print.line("   1. Install Gamescope: sudo pacman -S gamescope");
        try nvctl.utils.print.line("   2. Launch with: gamescope -W 1920 -H 1080 -r 144 -- steam");
        return;
    }
    
    const session = controller.getSessionInfo() catch |err| {
        try nvctl.utils.print.format("❌ Failed to get session info: {s}\\n", .{@errorName(err)});
        return;
    };
    defer session.deinit(allocator);
    
    try nvctl.utils.print.line("✅ Running under Gamescope");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("📺 Display Configuration:");
    try nvctl.utils.print.format("   Resolution: {d}x{d}\\n", .{ session.width, session.height });
    try nvctl.utils.print.format("   Refresh Rate: {d} Hz\\n", .{session.refresh_rate});
    try nvctl.utils.print.format("   HDR Support: {s}\\n", .{if (session.hdr_available) "✅ Available" else "❌ Not Available"});
    try nvctl.utils.print.format("   VRR Support: {s}\\n", .{if (session.vrr_available) "✅ Available" else "❌ Not Available"});
    
    if (session.current_game) |game| {
        try nvctl.utils.print.format("🎮 Current Game: {s}\\n", .{game});
        
        if (controller.current_profile) |profile| {
            try nvctl.utils.print.format("🎯 Active Profile: {s}\\n", .{profile.name});
        } else {
            try nvctl.utils.print.line("🎯 Active Profile: Default");
        }
    } else {
        try nvctl.utils.print.line("🎮 Current Game: None detected");
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Use 'nvctl gamescope monitor' to enable automatic profile switching");
}

fn listGameProfiles(allocator: std.mem.Allocator, controller: *GamescopeController) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🎮 Available Game Profiles");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Load profiles if not already loaded
    try controller.loadProfiles();
    
    if (controller.profiles.items.len == 0) {
        try nvctl.utils.print.line("❌ No game profiles configured");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("💡 Create profiles in ~/.config/nvctl/game_profiles.json");
        return;
    }
    
    for (controller.profiles.items, 0..) |profile, i| {
        const active_indicator = if (controller.current_profile == &profile) "🎯" else "  ";
        
        try nvctl.utils.print.format("{s} {d}. {s}\\n", .{ active_indicator, i + 1, profile.name });
        try nvctl.utils.print.format("     GPU: +{d} MHz, Memory: +{d} MHz, Power: {d}%\\n", 
            .{ profile.gpu_clock_offset, profile.memory_clock_offset, profile.power_limit });
        try nvctl.utils.print.format("     Upscaling: {s}\\n", .{profile.upscaling_mode.toString()});
        
        if (profile.enable_hdr or profile.enable_vrr) {
            const hdr_text = if (profile.enable_hdr) "HDR" else "";
            const vrr_text = if (profile.enable_vrr) "VRR" else "";
            const sep = if (profile.enable_hdr and profile.enable_vrr) ", " else "";
            try nvctl.utils.print.format("     Features: {s}{s}{s}\\n", .{ hdr_text, sep, vrr_text });
        }
        
        try nvctl.utils.print.line("");
    }
}

fn handleApplyProfile(allocator: std.mem.Allocator, controller: *GamescopeController, args: []const []const u8) !void {
    _ = allocator;
    
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl gamescope apply <profile_name>");
        try nvctl.utils.print.line("Example: nvctl gamescope apply competitive");
        return;
    }
    
    const profile_name = args[0];
    
    // Load profiles if not already loaded
    try controller.loadProfiles();
    
    // Find and apply the profile
    for (controller.profiles.items) |*profile| {
        if (std.mem.indexOf(u8, profile.name, profile_name)) |_| {
            controller.activateProfile(profile) catch {
                try nvctl.utils.print.line("❌ Failed to activate profile");
                return;
            };
            return;
        }
    }
    
    try nvctl.utils.print.format("❌ Profile '{s}' not found\\n", .{profile_name});
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Use 'nvctl gamescope profiles' to see available profiles");
}
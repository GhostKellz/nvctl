//! Comprehensive NVCTL Application Example
//! 
//! This file demonstrates the full capabilities of the enhanced nvctl
//! with GhostNV integration as outlined in GHOSTNV_INTEGRATION.md
//!
//! Features demonstrated:
//! - Complete GPU monitoring with real-time metrics
//! - Advanced thermal management with custom fan curves  
//! - Safe overclocking with stability testing
//! - Multi-display management with HDR support
//! - AI upscaling (DLSS) configuration and auto-tuning
//! - Variable Refresh Rate management with game profiles
//! - Memory optimization with zero-copy transfers
//! - Real-time performance monitoring loop

const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");
const integration = @import("ghostnv_integration.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.log.info("🚀 Starting Enhanced NVCTL with GhostNV Integration", .{});
    
    // Initialize all components
    var gpu_controller = integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    try gpu_controller.initializeDriver();
    
    var memory_manager = integration.MemoryManager.init(allocator, &gpu_controller);
    defer memory_manager.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &gpu_controller);
    defer monitoring.deinit();
    
    var thermal = integration.ThermalController.init(allocator, &gpu_controller, &monitoring);
    defer thermal.deinit();
    
    var overclocking = integration.OverclockingController.init(allocator, &gpu_controller, &monitoring);
    defer overclocking.deinit();
    
    var display = integration.DisplayController.init(allocator, &gpu_controller);
    defer display.deinit();
    
    var ai_upscaling = integration.AIUpscalingController.init(allocator, &gpu_controller, &monitoring);
    defer ai_upscaling.deinit();
    
    var vrr = integration.VRRManager.init(allocator, &gpu_controller, &display, &monitoring);
    defer vrr.deinit();
    
    std.log.info("✅ All controllers initialized successfully", .{});
    
    // Discover GPUs
    const gpu_count = gpu_controller.getGpuCount();
    std.log.info("🔍 Found {} NVIDIA GPU(s)", .{gpu_count});
    
    if (gpu_count == 0) {
        std.log.err("❌ No NVIDIA GPUs detected", .{});
        return;
    }
    
    // Process each GPU
    for (0..gpu_count) |i| {
        const gpu_id = @as(u32, @intCast(i));
        try processGPU(allocator, gpu_id, &gpu_controller, &memory_manager, &monitoring, 
                      &thermal, &overclocking, &display, &ai_upscaling, &vrr);
    }
    
    // Start comprehensive monitoring loop
    try runMonitoringLoop(allocator, &monitoring, gpu_count);
}

/// Process individual GPU with all enhanced features
fn processGPU(
    allocator: std.mem.Allocator,
    gpu_id: u32,
    gpu_controller: *integration.GPUController,
    memory_manager: *integration.MemoryManager,
    monitoring: *integration.MonitoringManager,
    thermal: *integration.ThermalController,
    overclocking: *integration.OverclockingController,
    display: *integration.DisplayController,
    ai_upscaling: *integration.AIUpscalingController,
    vrr: *integration.VRRManager,
) !void {
    _ = allocator;
    
    try gpu_controller.setActiveGpu(gpu_id);
    const gpu_info = try gpu_controller.getGpuInfo();
    defer gpu_info.deinit(gpu_controller.allocator);
    
    std.log.info("🎮 GPU {}: {} (Driver: {})", .{gpu_id, gpu_info.name, gpu_info.driver_version});
    std.log.info("  📊 VRAM: {} GB, Temp: {}°C, Power: {}W, Util: {}%", .{
        gpu_info.vram_total / (1024*1024*1024),
        gpu_info.temperature,
        gpu_info.power_usage,
        gpu_info.utilization
    });
    
    // 1. Setup Memory Management
    try setupMemoryOptimizations(memory_manager, gpu_id);
    
    // 2. Setup Monitoring with Alerts
    try setupMonitoring(monitoring, gpu_id);
    
    // 3. Configure Thermal Management
    try setupThermalManagement(thermal, gpu_id);
    
    // 4. Perform Safe Overclocking
    try performSafeOverclocking(overclocking, gpu_id);
    
    // 5. Setup Display Management
    try setupDisplayManagement(display, gpu_id);
    
    // 6. Configure AI Upscaling
    try setupAIUpscaling(ai_upscaling, gpu_id);
    
    // 7. Setup Variable Refresh Rate
    try setupVRR(vrr, display, gpu_id);
    
    std.log.info("✨ GPU {} fully configured with all enhanced features", .{gpu_id});
}

/// Setup memory optimizations with zero-copy transfers
fn setupMemoryOptimizations(memory_manager: *integration.MemoryManager, gpu_id: u32) !void {
    std.log.info("🧠 Setting up memory optimizations for GPU {}...", .{gpu_id});
    
    // Enable zero-copy transfers
    try memory_manager.enableZeroCopy();
    std.log.info("  ✅ Zero-copy transfers enabled", .{});
    
    // Create optimized memory pools
    const pool_config = integration.MemoryManager.MemoryPoolConfig{
        .pool_size = 64 * 1024 * 1024, // 64MB pool
        .block_size = 4096,
        .alignment = 256,
    };
    try memory_manager.createMemoryPool(gpu_id, pool_config);
    std.log.info("  ✅ Memory pool created (64MB)", .{});
    
    // Allocate GPU-optimized memory
    const vram_addr = try memory_manager.allocateGPUMemory(
        16 * 1024 * 1024, // 16MB
        .vram,
        .render_target
    );
    std.log.info("  ✅ VRAM allocated at 0x{X}", .{vram_addr});
    
    const stats = memory_manager.getMemoryStats();
    std.log.info("  📈 Memory Stats: {} blocks allocated, {d:.1f}% fragmentation", .{
        stats.allocated_blocks, stats.fragmentation_percent
    });
}

/// Setup comprehensive monitoring with alerts
fn setupMonitoring(monitoring: *integration.MonitoringManager, gpu_id: u32) !void {
    std.log.info("📊 Setting up monitoring for GPU {}...", .{gpu_id});
    
    // Register temperature alert
    try monitoring.setTemperatureAlert(gpu_id, 80, temperatureAlertCallback);
    std.log.info("  ✅ Temperature alert set (>80°C)", .{});
    
    // Start continuous monitoring
    try monitoring.startContinuousMonitoring(gpu_id);
    std.log.info("  ✅ Continuous monitoring started", .{});
    
    // Get initial metrics
    const metrics = try monitoring.getCurrentMetrics(gpu_id);
    std.log.info("  📊 Initial metrics: {}°C, {}% util, {} MB VRAM", .{
        @as(u32, @intFromFloat(metrics.temperature)),
        metrics.utilization,
        metrics.memory_used_mb
    });
}

/// Configure thermal management with custom profiles
fn setupThermalManagement(thermal: *integration.ThermalController, gpu_id: u32) !void {
    std.log.info("🌡️  Setting up thermal management for GPU {}...", .{gpu_id});
    
    // Set balanced thermal profile
    try thermal.setThermalProfile(gpu_id, .balanced);
    std.log.info("  ✅ Balanced thermal profile applied", .{});
    
    // Create custom fan curve for extreme cooling
    const extreme_fan_curve = integration.ThermalController.FanCurve{
        .points = [_]integration.ThermalController.FanCurvePoint{
            .{ .temp = 20, .speed = 40 },
            .{ .temp = 40, .speed = 60 },
            .{ .temp = 60, .speed = 80 },
            .{ .temp = 75, .speed = 100 },
            undefined, undefined, undefined, undefined,
        },
        .point_count = 4,
        .hysteresis = 2,
    };
    
    try thermal.setFanCurve(gpu_id, extreme_fan_curve);
    std.log.info("  ✅ Custom aggressive fan curve applied", .{});
}

/// Perform safe automatic overclocking
fn performSafeOverclocking(overclocking: *integration.OverclockingController, gpu_id: u32) !void {
    std.log.info("⚡ Performing safe overclocking for GPU {}...", .{gpu_id});
    
    const baseline = try overclocking.getClockSpeeds(gpu_id);
    std.log.info("  📊 Baseline clocks: Core={}MHz, Memory={}MHz", .{
        baseline.core_clock, baseline.memory_clock
    });
    
    // Perform automatic safe overclocking
    const profile = try overclocking.performSafeOverclock(gpu_id);
    defer overclocking.allocator.free(profile.name);
    
    std.log.info("  ✅ Auto-overclock complete!", .{});
    std.log.info("    🚀 Stable core: +{}MHz", .{profile.max_stable_core});
    std.log.info("    💾 Stable memory: +{}MHz", .{profile.max_stable_memory});
    std.log.info("    ✅ Validation: {}", .{profile.validated});
}

/// Setup comprehensive display management
fn setupDisplayManagement(display: *integration.DisplayController, gpu_id: u32) !void {
    _ = gpu_id;
    
    std.log.info("🖥️  Setting up display management...", .{});
    
    const display_count = try display.getConnectedDisplayCount();
    std.log.info("  🔍 Found {} connected displays", .{display_count});
    
    // Configure each display
    for (0..display_count) |i| {
        const display_id = @as(u32, @intCast(i));
        const display_info = try display.getDisplayInfo(display_id);
        defer display_info.deinit(display.allocator);
        
        std.log.info("  🖥️  Display {}: {} ({}x{}@{}Hz)", .{
            display_id,
            display_info.name,
            display_info.width,
            display_info.height,
            display_info.refresh_rate
        });
        
        // Enable HDR if supported
        if (display_info.supports_hdr) {
            try display.enableHDR(display_id);
            std.log.info("    ✅ HDR enabled", .{});
        }
        
        // Set optimal color settings
        try display.setColorSettings(display_id, .{
            .digital_vibrance = 63, // 63% vibrance
            .color_temperature = 6500, // 6500K
            .gamma = 2.2,
            .contrast = 1.0,
            .brightness = 1.0,
        });
        std.log.info("    ✅ Color settings optimized", .{});
    }
}

/// Configure AI upscaling with auto-tuning
fn setupAIUpscaling(ai_upscaling: *integration.AIUpscalingController, gpu_id: u32) !void {
    std.log.info("🤖 Setting up AI upscaling for GPU {}...", .{gpu_id});
    
    // Check current DLSS status
    const status = try ai_upscaling.getUpscalingStatus(gpu_id);
    std.log.info("  📊 Current status: {} ({}x{} -> {}x{})", .{
        @tagName(status.engine_type),
        status.render_resolution.width,
        status.render_resolution.height,
        status.output_resolution.width,
        status.output_resolution.height,
    });
    
    // Configure DLSS for gaming
    const dlss_settings = integration.AIUpscalingController.AIUpscalingSettings{
        .engine_type = .dlss,
        .mode = .balanced,
        .quality_preset = .balanced,
        .target_framerate = 120, // Target 120 FPS
        .max_render_resolution = .{ .width = 2560, .height = 1440 },
        .quality_preference = 0.6, // Slight bias toward quality
        .power_efficiency = false,
    };
    
    try ai_upscaling.enableAIUpscaling(gpu_id, dlss_settings);
    std.log.info("  ✅ DLSS configured for high-performance gaming", .{});
    
    // Enable adaptive auto-tuning
    try ai_upscaling.enableAutoTuning(gpu_id, .{
        .target_fps = 120,
        .quality_preference = 0.6,
        .power_efficiency = false,
    });
    std.log.info("  ✅ Auto-tuning enabled (target: 120 FPS)", .{});
}

/// Setup Variable Refresh Rate with game profiles
fn setupVRR(vrr: *integration.VRRManager, display: *integration.DisplayController, gpu_id: u32) !void {
    _ = gpu_id;
    
    std.log.info("🔄 Setting up Variable Refresh Rate...", .{});
    
    const display_count = try display.getConnectedDisplayCount();
    
    // Setup VRR for each compatible display
    for (0..display_count) |i| {
        const display_id = @as(u32, @intCast(i));
        const display_info = try display.getDisplayInfo(display_id);
        defer display_info.deinit(display.allocator);
        
        if (display_info.supports_vrr) {
            const vrr_config = integration.VRRManager.VRRConfig{
                .vrr_type = .gsync,
                .min_refresh_rate = 48,
                .max_refresh_rate = 165,
                .enable_lfc = true,
                .lfc_config = .{
                    .multiplier = 2.0,
                    .threshold_fps = 48.0,
                    .max_multiplier = 4.0,
                    .smooth_transitions = true,
                },
                .enable_smoothing = true,
                .smoothing_algorithm = .moderate,
            };
            
            try vrr.enableVRR(display_id, vrr_config);
            std.log.info("  ✅ VRR enabled on display {} (48-165Hz)", .{display_id});
            
            // Create Cyberpunk 2077 gaming profile
            try vrr.createGameVRRProfile("Cyberpunk 2077", 0x1234567890ABCDEF, .{
                .name = "", // Will be set by the function
                .process_hash = 0x1234567890ABCDEF,
                .vrr_type = .gsync,
                .preferred_refresh_range = .{ .min = 30, .max = 120 },
                .enable_lfc = true,
                .lfc_multiplier = 2.0,
                .enable_smoothing = true,
                .smoothing_strength = 0.7,
                .adaptive_vrr = true,
                .power_efficiency = false,
                .genre_optimization = .cinematic,
            });
            std.log.info("  ✅ Cyberpunk 2077 VRR profile created", .{});
        }
    }
}

/// Real-time monitoring loop with comprehensive metrics
fn runMonitoringLoop(allocator: std.mem.Allocator, monitoring: *integration.MonitoringManager, gpu_count: u32) !void {
    _ = allocator;
    
    std.log.info("🔄 Starting real-time monitoring loop...", .{});
    std.log.info("Press Ctrl+C to stop monitoring", .{});
    
    var loop_count: u32 = 0;
    while (loop_count < 30) { // Run for 30 seconds as demo
        // Clear screen and show header
        if (loop_count % 10 == 0) {
            std.log.info("", .{});
            std.log.info("📊 === NVCTL Real-Time GPU Monitoring === ", .{});
        }
        
        // Monitor each GPU
        for (0..gpu_count) |i| {
            const gpu_id = @as(u32, @intCast(i));
            const metrics = monitoring.getCurrentMetrics(gpu_id) catch continue;
            
            // Format comprehensive status
            std.log.info("🎮 GPU {}: {d:>3.0f}°C | {d:>3}% | {d:>4}W | {d:>5}MB VRAM | {d:>4}MHz Core", .{
                gpu_id,
                metrics.temperature,
                metrics.utilization,
                metrics.power_usage,
                metrics.memory_used_mb,
                metrics.core_clock_mhz,
            });
            
            // Check for thermal warnings
            if (metrics.temperature > 80) {
                std.log.warn("  ⚠️  High temperature detected on GPU {}", .{gpu_id});
            }
            
            // Check for high utilization
            if (metrics.utilization > 95) {
                std.log.info("  🔥 GPU {} running at maximum utilization", .{gpu_id});
            }
        }
        
        // Sleep for 1 second
        std.time.sleep(1_000_000_000);
        loop_count += 1;
    }
    
    std.log.info("✅ Monitoring loop completed successfully", .{});
}

/// Temperature alert callback
fn temperatureAlertCallback(alert: integration.MonitoringManager.Alert) void {
    std.log.warn("🚨 ALERT: {} - GPU {} temperature: {d:.1f}°C", .{
        @tagName(alert.severity), alert.gpu_id, alert.metric_value
    });
}
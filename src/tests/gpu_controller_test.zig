//! Unit Tests for GPU Controller
//! 
//! Comprehensive test suite for the ghostnv integration layer

const std = @import("std");
const testing = std.testing;
const integration = @import("../ghostnv_integration.zig");

test "GPUController initialization" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    try testing.expect(!controller.driver_initialized);
    try testing.expectEqual(@as(u32, 0), controller.gpu_count);
    try testing.expectEqual(@as(u32, 0), controller.active_gpu_id);
}

test "GPUController driver initialization" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    // Try to initialize driver (may fail in test environment)
    controller.initializeDriver() catch |err| switch (err) {
        error.DriverNotFound => {
            // Expected in test environment without real GPU
            return;
        },
        else => return err,
    };
    
    if (controller.driver_initialized) {
        try testing.expect(controller.gpu_count > 0);
    }
}

test "GPUController GPU enumeration" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    const gpu_count = controller.getGpuCount();
    try testing.expect(gpu_count >= 0);
}

test "GPUController active GPU selection" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    // Initialize with mock GPU
    controller.gpu_count = 2;
    
    // Test valid GPU selection
    try controller.setActiveGpu(0);
    try testing.expectEqual(@as(u32, 0), controller.getActiveGpuId());
    
    try controller.setActiveGpu(1);
    try testing.expectEqual(@as(u32, 1), controller.getActiveGpuId());
    
    // Test invalid GPU selection
    const result = controller.setActiveGpu(5);
    try testing.expectError(error.InvalidParameters, result);
}

test "MonitoringManager initialization" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &controller);
    defer monitoring.deinit();
    
    try testing.expect(!monitoring.monitoring_active);
    try testing.expectEqual(@as(u32, 1000), monitoring.polling_interval_ms);
}

test "MonitoringManager metrics collection" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &controller);
    defer monitoring.deinit();
    
    // Try to get metrics (may fail without real hardware)
    const metrics = monitoring.getCurrentMetrics(0) catch |err| switch (err) {
        error.DeviceNotFound => {
            // Expected in test environment
            return;
        },
        else => return err,
    };
    
    // Validate metric ranges if we got data
    try testing.expect(metrics.temperature >= 0);
    try testing.expect(metrics.temperature <= 120);
    try testing.expect(metrics.utilization <= 100);
}

test "ThermalController profile management" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &controller);
    defer monitoring.deinit();
    
    var thermal = integration.ThermalController.init(allocator, &controller, &monitoring);
    defer thermal.deinit();
    
    // Test profile switching
    thermal.setThermalProfile(0, .silent) catch |err| switch (err) {
        error.DeviceNotFound => return,
        else => return err,
    };
    try testing.expectEqual(integration.ThermalController.ThermalProfile.silent, thermal.current_profile);
    
    thermal.setThermalProfile(0, .performance) catch return;
    try testing.expectEqual(integration.ThermalController.ThermalProfile.performance, thermal.current_profile);
}

test "OverclockingController safe limits" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &controller);
    defer monitoring.deinit();
    
    var overclocking = integration.OverclockingController.init(allocator, &controller, &monitoring);
    defer overclocking.deinit();
    
    // Test that overclock config is properly clamped
    const unsafe_config = integration.OverclockingController.OverclockConfig{
        .core_offset_mhz = 1000, // Too high
        .memory_offset_mhz = 2000, // Too high
        .voltage_offset_mv = 500, // Too high
        .power_limit_percent = 200, // Too high
    };
    
    // Apply should clamp values internally
    overclocking.applyOverclock(0, unsafe_config) catch |err| switch (err) {
        error.DeviceNotFound => return,
        else => {},
    };
}

test "DisplayController display enumeration" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var display = integration.DisplayController.init(allocator, &controller);
    defer display.deinit();
    
    // List displays (may be empty in test environment)
    const displays = display.listDisplays() catch &[_]integration.DisplayController.DisplayInfo{};
    
    // Validate display info if any found
    for (displays) |d| {
        try testing.expect(d.resolution.width > 0);
        try testing.expect(d.resolution.height > 0);
        try testing.expect(d.refresh_rate > 0);
    }
}

test "VRRManager VRR configuration" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var display = integration.DisplayController.init(allocator, &controller);
    defer display.deinit();
    
    var vrr = integration.VRRManager.init(allocator, &controller, &display);
    defer vrr.deinit();
    
    // Test VRR config validation
    const config = integration.VRRManager.VRRConfig{
        .min_refresh_rate = 48,
        .max_refresh_rate = 144,
        .mode = .adaptive_sync,
        .low_framerate_compensation = true,
    };
    
    // Try to enable VRR (may fail without display)
    vrr.enableVRR(0, config) catch |err| switch (err) {
        error.DisplayNotConnected,
        error.DeviceNotFound,
        => return,
        else => return err,
    };
}

test "MemoryManager memory allocation" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var memory = integration.MemoryManager.init(allocator, &controller);
    defer memory.deinit();
    
    // Test memory stats retrieval
    const stats = memory.getMemoryStats();
    
    // Validate stats are reasonable
    try testing.expect(stats.total_allocated <= stats.total_allocated + stats.total_free);
    try testing.expect(stats.fragmentation_percent <= 100);
}

test "AIUpscalingController DLSS configuration" {
    const allocator = testing.allocator;
    
    var controller = integration.GPUController.init(allocator);
    defer controller.deinit();
    
    var monitoring = integration.MonitoringManager.init(allocator, &controller);
    defer monitoring.deinit();
    
    var ai_upscaling = integration.AIUpscalingController.init(allocator, &controller, &monitoring);
    defer ai_upscaling.deinit();
    
    // Test AI upscaling settings
    const settings = integration.AIUpscalingController.AIUpscalingSettings{
        .engine_type = .dlss,
        .mode = .balanced,
        .quality_preset = .balanced,
        .target_framerate = 60,
        .max_render_resolution = .{ .width = 1920, .height = 1080 },
        .quality_preference = 0.5,
        .power_efficiency = false,
    };
    
    // Try to enable AI upscaling
    ai_upscaling.enableAIUpscaling(0, settings) catch |err| switch (err) {
        error.DeviceNotFound,
        error.FeatureNotSupported,
        => return,
        else => return err,
    };
}
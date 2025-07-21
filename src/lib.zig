const std = @import("std");

// Utilities
pub const utils = @import("utils.zig");

// GhostNV Integration Layer
pub const ghostnv_integration = @import("ghostnv_integration.zig");

// Core modules
pub const gpu = @import("gpu.zig");
pub const display = @import("display.zig");
pub const overclocking = @import("overclocking.zig");
pub const vrr = @import("vrr.zig");
pub const upscaling = @import("upscaling.zig");
pub const drivers = @import("drivers.zig");
pub const fan = @import("fan.zig");
pub const power = @import("power.zig");
pub const vibrance = @import("vibrance.zig");

// GUI module (only available in non-testing builds)
pub const gui = @import("gui.zig");

// Common error types
pub const NvctlError = error{
    GpuNotFound,
    DriverNotLoaded,
    PermissionDenied,
    UnsupportedOperation,
    InvalidArgument,
    HardwareError,
    OutOfMemory,
    Unexpected,
};

// Common result type
pub const Result = union(enum) {
    ok: void,
    err: NvctlError,
};

// GPU information structure
pub const GpuInfo = struct {
    name: []const u8,
    driver_version: []const u8,
    vram_total: u64,
    vram_used: u64,
    temperature: f32,
    power_usage: u32,
    utilization: u8,
    clock_graphics: u32,
    clock_memory: u32,
};

// Display information structure
pub const DisplayInfo = struct {
    id: u32,
    name: []const u8,
    manufacturer: []const u8,
    model: []const u8,
    connection_type: []const u8,
    resolution_width: u32,
    resolution_height: u32,
    refresh_rate: u32,
    hdr_enabled: bool,
    hdr_capable: bool,
    vibrance: f32,
};

// Overclocking profile structure
pub const OverclockProfile = struct {
    gpu_clock_offset: i32,
    memory_clock_offset: i32,
    power_limit: u8,
    temp_limit: u8,
    fan_curve: []const FanCurvePoint,
};

pub const FanCurvePoint = struct {
    temp: u8,
    fan_speed: u8,
};

// VRR settings structure
pub const VrrSettings = struct {
    enabled: bool,
    min_refresh: u32,
    max_refresh: u32,
    display_name: []const u8,
};

// Upscaling technology enum
pub const UpscalingTechnology = enum {
    dlss,
    fsr,
    xess,
    native,
};

// Upscaling quality enum
pub const UpscalingQuality = enum {
    performance,
    balanced,
    quality,
    ultra,
};

test "basic library functionality" {
    const testing = std.testing;

    // Test error types
    const err: NvctlError = NvctlError.GpuNotFound;
    try testing.expect(err == NvctlError.GpuNotFound);

    // Test structures
    const gpu_info = GpuInfo{
        .name = "RTX 4090",
        .driver_version = "545.29.06",
        .vram_total = 24 * 1024 * 1024 * 1024, // 24GB
        .vram_used = 2 * 1024 * 1024 * 1024, // 2GB
        .temperature = 65.0,
        .power_usage = 350,
        .utilization = 75,
        .clock_graphics = 2520,
        .clock_memory = 10501,
    };

    try testing.expect(gpu_info.vram_total > gpu_info.vram_used);
    try testing.expect(gpu_info.temperature > 0);
}

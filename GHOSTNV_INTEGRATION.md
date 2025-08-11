# GhostNV Integration Guide

**GhostNV - Pure Zig NVIDIA Open Driver Integration**

This document provides comprehensive integration instructions for leveraging the GhostNV driver in GhostKernel and NVCTL applications.

## Table of Contents

- [Overview](#overview)
- [GhostKernel Integration](#ghostkernel-integration)
- [NVCTL Integration](#nvctl-integration)
- [API Reference](#api-reference)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Overview

GhostNV is a pure Zig implementation of an open NVIDIA driver designed for seamless integration with GhostKernel and NVCTL. It provides:

- **Native Kernel Integration**: Embedded directly in GhostKernel (no DKMS required)
- **Real-Time Performance**: Ultra-low latency optimizations for gaming and professional workloads
- **Comprehensive GPU Control**: Full hardware access through clean Zig APIs
- **Modern Features**: DLSS 3+, RTX IO, Variable Refresh Rate, RTX Voice integration

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Applications                            │
├─────────────────┬───────────────────┬───────────────────────┤
│    Game/App     │      NVCTL        │    Audio/Display      │
├─────────────────┼───────────────────┼───────────────────────┤
│  GhostNV APIs   │   Control APIs    │   Wayland/PipeWire    │
├─────────────────┼───────────────────┼───────────────────────┤
│                 GhostNV Driver Core                         │
├─────────────────────────────────────────────────────────────┤
│              GhostKernel Native Interface                   │
├─────────────────────────────────────────────────────────────┤
│                    GhostKernel                              │
└─────────────────────────────────────────────────────────────┘
```

## GhostKernel Integration

### Native Driver Embedding

GhostNV is designed to be compiled directly into GhostKernel, eliminating the need for DKMS or external modules.

#### 1. Kernel Configuration

Add to your GhostKernel `Kconfig`:

```kconfig
config GHOSTNV_DRIVER
    bool "GhostNV NVIDIA Driver Support"
    depends on PCI && X86_64
    select DRM
    select DRM_KMS_HELPER
    help
      Enable native GhostNV NVIDIA driver support.
      This provides full GPU acceleration without external modules.

config GHOSTNV_REALTIME
    bool "GhostNV Real-Time Optimizations"
    depends on GHOSTNV_DRIVER && PREEMPT_RT
    help
      Enable ultra-low latency optimizations for gaming and professional use.
```

#### 2. Build Integration

In your GhostKernel `Makefile`:

```makefile
# Add GhostNV to kernel build
obj-$(CONFIG_GHOSTNV_DRIVER) += ghostnv/

# Include GhostNV headers
ccflags-$(CONFIG_GHOSTNV_DRIVER) += -I$(src)/ghostnv/include
```

#### 3. Kernel Interface Layer

Include the GhostKernel interface in your kernel:

```c
// ghostkernel/drivers/gpu/ghostnv/ghostnv_kernel.c
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/dma-mapping.h>
#include "ghostnv_interface.h"

// GhostKernel function table for GhostNV
static const struct ghostnv_kernel_functions ghostkernel_funcs = {
    .alloc_dma_memory = ghostkernel_alloc_dma,
    .free_dma_memory = ghostkernel_free_dma,
    .map_physical_memory = ghostkernel_map_physical,
    .unmap_physical_memory = ghostkernel_unmap_physical,
    .register_irq = ghostkernel_register_irq,
    .unregister_irq = ghostkernel_unregister_irq,
    .pci_read_config32 = ghostkernel_pci_read32,
    .pci_write_config32 = ghostkernel_pci_write32,
    .get_uptime_seconds = ghostkernel_get_uptime,
    .enable_realtime_scheduling = ghostkernel_enable_rt,
};

// Initialize GhostNV driver
static int ghostnv_init(void)
{
    void *ghostnv_handle = ghostnv_kernel_interface_init(&ghostkernel_funcs);
    if (!ghostnv_handle) {
        pr_err("Failed to initialize GhostNV driver\n");
        return -ENODEV;
    }
    
    pr_info("GhostNV driver initialized successfully\n");
    return 0;
}

module_init(ghostnv_init);
```

#### 4. Header-Only Integration (Alternative)

For simpler integration, use the header-only mode:

```c
// ghostkernel/include/ghostnv.h
#define GHOSTNV_HEADER_ONLY
#include "ghostnv_embedded.h"

// In your kernel initialization:
ghostnv_embedded_init();
```

### Memory Management Integration

GhostNV provides advanced memory management optimized for GhostKernel:

```c
// Example: Allocate GPU-accessible DMA memory
struct ghostnv_dma_allocation {
    void *virtual_addr;
    dma_addr_t physical_addr;
    size_t size;
};

static struct ghostnv_dma_allocation alloc_gpu_memory(size_t size)
{
    struct ghostnv_dma_allocation alloc = {0};
    
    // Use GhostKernel's optimized DMA allocator
    alloc.virtual_addr = dma_alloc_coherent(&pdev->dev, size, 
                                           &alloc.physical_addr, 
                                           GFP_KERNEL | __GFP_COMP);
    if (alloc.virtual_addr)
        alloc.size = size;
    
    return alloc;
}
```

### Real-Time Scheduling Integration

Enable real-time optimizations in GhostKernel:

```c
// ghostkernel/kernel/sched/rt_gpu.c
void ghostkernel_enable_gpu_rt_scheduling(struct task_struct *task)
{
    struct sched_param param = { .sched_priority = 95 };
    
    // Set real-time priority for GPU work
    sched_setscheduler(task, SCHED_FIFO, &param);
    
    // Lock memory to prevent swapping
    if (current->mm)
        current->mm->locked_vm = current->mm->total_vm;
}
```

## NVCTL Integration

NVCTL provides a comprehensive GPU management interface built on GhostNV APIs.

### 1. Basic Setup

```zig
// nvctl_main.zig
const std = @import("std");
const ghostnv = @import("ghostnv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize GhostNV driver interface
    const driver = try ghostnv.Driver.init(allocator);
    defer driver.deinit();
    
    // Initialize NVCTL controllers
    const monitoring = try ghostnv.MonitoringManager.init(allocator, driver);
    const thermal = try ghostnv.ThermalController.init(allocator, driver, monitoring);
    const overclocking = try ghostnv.OverclockingController.init(allocator, driver, monitoring);
    
    defer {
        overclocking.deinit();
        thermal.deinit();
        monitoring.deinit();
    }
    
    // Run NVCTL main loop
    try nvctlMainLoop(driver, monitoring, thermal, overclocking);
}
```

### 2. GPU Monitoring

```zig
// Monitor GPU metrics
fn monitorGPU(monitoring: *ghostnv.MonitoringManager, gpu_id: u32) !void {
    const metrics = try monitoring.getCurrentMetrics(gpu_id);
    
    std.log.info("GPU {}: {}°C, {}% utilization, {} MB VRAM used", .{
        gpu_id,
        metrics.temperature,
        metrics.gpu_utilization,
        metrics.memory_used_mb,
    });
    
    // Set up alerts
    if (metrics.temperature > 80) {
        std.log.warn("GPU {} temperature high: {}°C", .{ gpu_id, metrics.temperature });
        
        // Auto-adjust fan curve
        const thermal = getThermalController();
        try thermal.setThermalProfile(gpu_id, .performance);
    }
}
```

### 3. Overclocking Control

```zig
// Safe overclocking with stability testing
fn performSafeOverclock(oc: *ghostnv.OverclockingController, gpu_id: u32) !void {
    // Get current clocks
    const baseline = try oc.getClockSpeeds(gpu_id);
    std.log.info("Baseline clocks - Core: {}MHz, Memory: {}MHz", .{
        baseline.core_clock, baseline.memory_clock
    });
    
    // Gradual overclocking with stability testing
    var core_offset: i32 = 50; // Start with +50MHz
    
    while (core_offset <= 200) : (core_offset += 25) {
        const oc_config = ghostnv.OverclockConfig{
            .core_offset_mhz = core_offset,
            .memory_offset_mhz = 0, // Memory later
            .voltage_offset_mv = 0,
            .power_limit_percent = 110,
        };
        
        try oc.applyOverclock(gpu_id, oc_config);
        
        // Run stability test
        const stability = try oc.runStabilityTest(gpu_id, .{
            .duration_seconds = 60,
            .test_type = .gpu_stress,
            .temperature_limit = 85,
        });
        
        if (!stability.stable) {
            // Revert to last stable settings
            core_offset -= 25;
            const stable_config = ghostnv.OverclockConfig{
                .core_offset_mhz = core_offset,
                .memory_offset_mhz = 0,
                .voltage_offset_mv = 0,
                .power_limit_percent = 110,
            };
            try oc.applyOverclock(gpu_id, stable_config);
            break;
        }
        
        std.log.info("Stable at +{}MHz core clock", .{core_offset});
    }
}
```

### 4. Display Management

```zig
// Multi-display setup with HDR
fn setupMultiDisplay(display: *ghostnv.DisplayController) !void {
    const display_count = try display.getConnectedDisplayCount();
    std.log.info("Found {} connected displays", .{display_count});
    
    for (0..display_count) |i| {
        const display_id = @as(u32, @intCast(i));
        const info = try display.getDisplayInfo(display_id);
        
        std.log.info("Display {}: {} ({}x{})", .{
            display_id, info.name, info.width, info.height
        });
        
        // Enable HDR if supported
        if (info.supports_hdr) {
            try display.setHDRMode(display_id, true);
            std.log.info("Enabled HDR for display {}", .{display_id});
        }
        
        // Configure optimal color settings
        try display.setColorSettings(display_id, .{
            .digital_vibrance = 63, // 63% vibrance
            .color_temperature = 6500, // 6500K
            .gamma = 2.2,
            .contrast = 1.0,
            .brightness = 1.0,
        });
    }
}
```

### 5. AI Upscaling Integration

```zig
// DLSS configuration
fn configureDLSS(ai: *ghostnv.AIUpscalingController, gpu_id: u32) !void {
    // Check DLSS support
    const status = try ai.getUpscalingStatus(gpu_id);
    if (!status.enabled) {
        // Enable DLSS with balanced settings
        const settings = ghostnv.AIUpscalingSettings{
            .engine_type = .dlss,
            .mode = .balanced,
            .quality_preset = .balanced,
            .target_framerate = 60,
            .max_render_resolution = .{ .width = 1920, .height = 1080 },
            .quality_preference = 0.5, // Balanced
            .power_efficiency = false,
        };
        
        try ai.enableAIUpscaling(gpu_id, settings);
        
        // Enable auto-tuning for optimal performance
        try ai.enableAutoTuning(gpu_id, .{
            .target_fps = 60,
            .quality_preference = 0.5,
            .power_efficiency = false,
        });
    }
    
    std.log.info("DLSS Status: {} ({}x{} -> {}x{})", .{
        @tagName(status.engine_type),
        status.render_resolution.width,
        status.render_resolution.height,
        status.output_resolution.width,
        status.output_resolution.height,
    });
}
```

### 6. Variable Refresh Rate

```zig
// VRR setup with game profiles
fn setupVRR(vrr: *ghostnv.VRRManager, display_id: u32) !void {
    const vrr_config = ghostnv.VRRConfig{
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
    
    // Create gaming profile
    try vrr.createGameVRRProfile("Cyberpunk 2077", 0x1234567890ABCDEF, .{
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
}
```

## API Reference

### Core Driver APIs

```zig
// Driver initialization
const driver = try ghostnv.Driver.init(allocator, memory_manager);

// GPU information
const gpu_info = try driver.queryGPUInfo();
const gpu_count = try driver.getGPUCount();

// Basic GPU control
try driver.setCoreClock(gpu_id, offset_mhz);
try driver.setMemoryClock(gpu_id, offset_mhz);
try driver.setPowerLimit(gpu_id, limit_watts);
```

### Monitoring APIs

```zig
// Real-time monitoring
const monitoring = try ghostnv.MonitoringManager.init(allocator, driver);
const metrics = try monitoring.getCurrentMetrics(gpu_id);

// Historical data
const history = try monitoring.getPerformanceHistory(gpu_id, duration_minutes);

// Alerts
try monitoring.setTemperatureAlert(gpu_id, 85, alertCallback);
```

### Thermal Control APIs

```zig
// Thermal management
const thermal = try ghostnv.ThermalController.init(allocator, driver, monitoring);

// Fan control
try thermal.setFanSpeed(gpu_id, speed_percent);
try thermal.setThermalProfile(gpu_id, .performance);

// Custom fan curves
const fan_curve = ghostnv.FanCurve{
    .points = [_]ghostnv.FanCurvePoint{
        .{ .temp = 30, .speed = 20 },
        .{ .temp = 60, .speed = 50 },
        .{ .temp = 80, .speed = 80 },
        .{ .temp = 90, .speed = 100 },
    },
    .point_count = 4,
    .hysteresis = 3,
};
try thermal.setFanCurve(gpu_id, fan_curve);
```

### Display APIs

```zig
// Display management
const display = try ghostnv.DisplayController.init(allocator, memory_manager);

// Multi-display setup
const count = try display.getConnectedDisplayCount();
for (0..count) |i| {
    const display_id = @as(u32, @intCast(i));
    try display.setHDRMode(display_id, true);
    try display.setDigitalVibrance(display_id, 63);
}
```

### Audio Integration APIs

```zig
// PipeWire integration
const audio = try ghostnv.PipeWireGhostKernelIntegration.init(allocator, rtx_voice, memory_manager);

// Ultra-low latency mode
try audio.enableGhostKernelMode();

// RTX Voice
try audio.enableRTXVoice(true, 0.8); // 80% noise suppression
```

## Performance Optimization

### Memory Optimization

```zig
// Enable zero-copy transfers
try memory_manager.enableZeroCopy();

// Allocate GPU-optimized memory
const gpu_memory = try memory_manager.allocateGPUMemory(
    buffer_size,
    .vram,
    .render_target
);

// Use memory pools for frequent allocations
const pool_config = ghostnv.MemoryPoolConfig{
    .pool_size = 64 * 1024 * 1024, // 64MB
    .block_size = 4096,
    .alignment = 256,
};
const pool = try ghostnv.MemoryPool.init(allocator, pool_config);
```

### Real-Time Optimizations

```zig
// Enable real-time scheduling
try kernel_interface.enableRealTimeScheduling(95);

// Lock memory to prevent swapping
try kernel_interface.lockMemory();

// Use high-resolution timers
const timer = try kernel_interface.createTimer(timerCallback, userdata);
try kernel_interface.setTimer(timer, 1); // 1ms precision
```

### Zen4 3D V-Cache Optimization

```zig
// Initialize V-Cache optimizer
const vcache = try ghostnv.Zen4VCacheOptimizer.init(allocator, topology);

// Allocate V-Cache optimized memory
const vcache_memory = try vcache.allocateVCacheOptimized(
    size,
    alignment,
    .gpu_workload
);
```

## Troubleshooting

### Common Issues

#### 1. Build Errors

```bash
# Missing dependencies
zig build --help  # Check available targets
zig build -Dtarget=x86_64-linux  # Specify target

# Clean rebuild
rm -rf .zig-cache zig-out/
zig build
```

#### 2. Runtime Issues

```zig
// Enable debug logging
try ghostnv.setLogLevel(.debug);

// Check GPU detection
const gpu_count = try driver.getGPUCount();
if (gpu_count == 0) {
    std.log.err("No NVIDIA GPUs detected");
    return error.NoGPUFound;
}

// Verify kernel interface
const stats = kernel_interface.getKernelStats();
std.log.info("Kernel mode: {}, version: {}.{}.{}", .{
    stats.embedded_mode, 
    stats.kernel_version.major,
    stats.kernel_version.minor,
    stats.kernel_version.patch
});
```

#### 3. Performance Issues

```zig
// Check memory allocation efficiency
const memory_stats = memory_manager.getMemoryStats();
std.log.info("Cache hit rate: {d:.1f}%", .{
    @as(f32, @floatFromInt(memory_stats.cache_hits)) * 100.0 / 
    @as(f32, @floatFromInt(memory_stats.allocations))
});

// Monitor interrupt latency
const interrupt_stats = interrupt_manager.getInterruptStats();
std.log.info("Avg interrupt latency: {}ns", .{interrupt_stats.average_processing_time_ns});
```

### Debug Configuration

```zig
// Enable comprehensive debugging
const debug_config = ghostnv.DebugConfig{
    .enable_memory_tracking = true,
    .enable_performance_counters = true,
    .enable_interrupt_tracing = true,
    .log_level = .debug,
};

try ghostnv.enableDebugMode(debug_config);
```

## Examples

### Complete NVCTL Application

```zig
// nvctl_example.zig - Complete GPU management example
const std = @import("std");
const ghostnv = @import("ghostnv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize all components
    const memory_manager = try ghostnv.KernelMemoryManager.init(allocator, kernel_interface);
    const driver = try ghostnv.Driver.init(allocator, memory_manager);
    const monitoring = try ghostnv.MonitoringManager.init(allocator, driver);
    const thermal = try ghostnv.ThermalController.init(allocator, driver, monitoring);
    const overclocking = try ghostnv.OverclockingController.init(allocator, driver, monitoring);
    const display = try ghostnv.DisplayController.init(allocator, memory_manager);
    const ai_upscaling = try ghostnv.AIUpscalingController.init(allocator, driver, monitoring);
    const vrr = try ghostnv.VRRManager.init(allocator, driver, display, monitoring);
    
    defer {
        vrr.deinit();
        ai_upscaling.deinit();
        display.deinit();
        overclocking.deinit();
        thermal.deinit();
        monitoring.deinit();
        driver.deinit();
        memory_manager.deinit();
    }
    
    // Discover GPUs
    const gpu_count = try driver.getGPUCount();
    std.log.info("Found {} NVIDIA GPU(s)", .{gpu_count});
    
    for (0..gpu_count) |i| {
        const gpu_id = @as(u32, @intCast(i));
        const gpu_info = try driver.queryGPUInfo();
        
        std.log.info("GPU {}: {} ({}MB VRAM)", .{
            gpu_id, gpu_info.name, gpu_info.memory_total_mb
        });
        
        // Set up monitoring
        try monitoring.startContinuousMonitoring(gpu_id);
        
        // Configure thermal management
        try thermal.setThermalProfile(gpu_id, .balanced);
        
        // Enable VRR for connected displays
        const display_count = try display.getConnectedDisplayCount();
        for (0..display_count) |j| {
            const display_id = @as(u32, @intCast(j));
            try setupOptimalVRR(vrr, display_id);
        }
        
        // Configure AI upscaling
        try configureDLSSForGaming(ai_upscaling, gpu_id);
    }
    
    // Main monitoring loop
    while (true) {
        for (0..gpu_count) |i| {
            const gpu_id = @as(u32, @intCast(i));
            const metrics = try monitoring.getCurrentMetrics(gpu_id);
            
            // Print status
            std.log.info("GPU {}: {}°C | {}% | {} MB", .{
                gpu_id,
                metrics.temperature,
                metrics.gpu_utilization,
                metrics.memory_used_mb,
            });
        }
        
        std.time.sleep(1_000_000_000); // 1 second
    }
}

fn setupOptimalVRR(vrr: *ghostnv.VRRManager, display_id: u32) !void {
    const config = ghostnv.VRRConfig{
        .vrr_type = .gsync,
        .min_refresh_rate = 48,
        .max_refresh_rate = 165,
        .enable_lfc = true,
        .lfc_config = .{},
        .enable_smoothing = true,
        .smoothing_algorithm = .moderate,
    };
    
    try vrr.enableVRR(display_id, config);
    std.log.info("VRR enabled for display {}", .{display_id});
}

fn configureDLSSForGaming(ai: *ghostnv.AIUpscalingController, gpu_id: u32) !void {
    const settings = ghostnv.AIUpscalingSettings{
        .engine_type = .dlss,
        .mode = .balanced,
        .quality_preset = .balanced,
        .target_framerate = 60,
        .max_render_resolution = .{ .width = 1920, .height = 1080 },
        .quality_preference = 0.5,
        .power_efficiency = false,
    };
    
    try ai.enableAIUpscaling(gpu_id, settings);
    try ai.enableAutoTuning(gpu_id, .{
        .target_fps = 60,
        .quality_preference = 0.5,
        .power_efficiency = false,
    });
    
    std.log.info("DLSS configured for GPU {}", .{gpu_id});
}
```

### GhostKernel Module Integration

```c
// ghostkernel_ghostnv.c - Kernel module integration
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/pci.h>

// GhostNV interface
extern void* ghostnv_kernel_interface_init(void* kernel_funcs);
extern void ghostnv_kernel_interface_deinit(void* interface);

static void* ghostnv_interface = NULL;

// GhostKernel function implementations
static void* ghostkernel_alloc_dma(size_t size, uint32_t flags)
{
    return dma_alloc_coherent(&nvidia_pdev->dev, size, &dma_handle, GFP_KERNEL);
}

static void ghostkernel_free_dma(void* addr, size_t size)
{
    dma_free_coherent(&nvidia_pdev->dev, size, addr, dma_handle);
}

// ... (other kernel function implementations)

static const struct ghostnv_kernel_functions ghostkernel_funcs = {
    .allocDMAMemory = ghostkernel_alloc_dma,
    .freeDMAMemory = ghostkernel_free_dma,
    .mapPhysicalMemory = ghostkernel_map_physical,
    .unmapPhysicalMemory = ghostkernel_unmap_physical,
    .virtToPhys = virt_to_phys,
    .pciReadConfig32 = ghostkernel_pci_read32,
    .pciWriteConfig32 = ghostkernel_pci_write32,
    .registerIRQ = ghostkernel_register_irq,
    .unregisterIRQ = ghostkernel_unregister_irq,
    .getUptimeSeconds = get_seconds,
    .setRealtimePriority = ghostkernel_set_rt_priority,
    .setNormalPriority = ghostkernel_set_normal_priority,
    .lockMemory = ghostkernel_lock_memory,
    .unlockMemory = ghostkernel_unlock_memory,
};

static int __init ghostnv_module_init(void)
{
    printk(KERN_INFO "GhostNV: Initializing native NVIDIA driver\n");
    
    ghostnv_interface = ghostnv_kernel_interface_init(&ghostkernel_funcs);
    if (!ghostnv_interface) {
        printk(KERN_ERR "GhostNV: Failed to initialize driver interface\n");
        return -ENODEV;
    }
    
    printk(KERN_INFO "GhostNV: Driver initialized successfully\n");
    return 0;
}

static void __exit ghostnv_module_exit(void)
{
    if (ghostnv_interface) {
        ghostnv_kernel_interface_deinit(ghostnv_interface);
        ghostnv_interface = NULL;
    }
    
    printk(KERN_INFO "GhostNV: Driver unloaded\n");
}

module_init(ghostnv_module_init);
module_exit(ghostnv_module_exit);

MODULE_LICENSE("MIT");
MODULE_AUTHOR("GhostNV Team");
MODULE_DESCRIPTION("GhostNV Native NVIDIA Driver for GhostKernel");
MODULE_VERSION("1.0.0");
```

---

## Additional Resources

- **GhostNV Source**: `/data/projects/ghostnv/zig-nvidia/src/`
- **API Documentation**: Generated from source with `zig build docs`
- **Performance Tuning**: See individual controller documentation
- **Debugging**: Enable debug mode with `GHOSTNV_DEBUG=1`

## Contributing

GhostNV is built entirely in Zig for maximum performance and safety. Contributions should follow:

1. **Zig Style Guide**: Use `zig fmt` for consistent formatting
2. **Memory Safety**: No manual memory management, use allocators
3. **Error Handling**: Explicit error types, no silent failures
4. **Testing**: All new features must include unit tests
5. **Documentation**: Comprehensive doc comments for public APIs

## License

GhostNV is released under the MIT License, ensuring maximum compatibility with both open source and proprietary projects.

---

**GhostNV - Unleashing NVIDIA GPU Power with Pure Zig Performance** 🚀
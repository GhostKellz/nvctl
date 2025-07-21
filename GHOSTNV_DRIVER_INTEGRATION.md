# NVCTL Integration with GhostNV

This document outlines the integration strategy for connecting your Zig-based NVIDIA control project (`nvctl`) with the GhostNV API and driver infrastructure.

## Current NVCTL State

### ✅ Implemented Features
- GPU Information - Real hardware detection with driver version
- Beautiful CLI Output - Unicode graphics, color-coded sections  
- Comprehensive Help System - Matches original nvcontrol specification
- Safety-First Design - Graceful error handling, no crashes
- Memory Management - Proper allocation/deallocation (minor leak to fix)

### 🎯 Integration Priorities

#### High Priority (Ready for GhostNV Integration)
1. **Display Management** - Multi-monitor, vibrance control, HDR
2. **VRR Control** - Wayland compositor integration (KDE/GNOME/Hyprland)
3. **Memory Leak Fix** - Clean up allocations in GPU detection

#### Medium Priority
1. **Overclocking** - Safe limits, stress testing, profile management
2. **Upscaling** - DLSS/FSR/XeSS game profile system
3. **GhostNV Hardware Control** - Replace stubs with real hardware control

#### Lower Priority
1. **Fan Control** - RPM monitoring, custom curves
2. **Driver Management** - Package manager integration
3. **GUI Implementation** - Jaguar-based interface

## GhostNV Integration Architecture

### Core Components to Leverage

#### 1. Digital Vibrance Control
```zig
// Enhanced vibrance control with per-display precision
pub const VibranceController = struct {
    display_manager: *ghostnv.DisplayController,
    
    pub fn setDigitalVibrance(self: *VibranceController, display_id: u32, level: i32) !void {
        // Range: -1024 to 1023 (NVIDIA standard)
        if (level < -1024 or level > 1023) return error.InvalidVibranceLevel;
        try self.display_manager.setDigitalVibrance(display_id, level);
    }
    
    pub fn getVibranceRange(self: *VibranceController, display_id: u32) !struct { min: i32, max: i32 } {
        return self.display_manager.getVibranceCapabilities(display_id);
    }
};
```

#### 2. DLSS Integration
```zig
// DLSS control through GhostNV's AI upscaling subsystem
pub const DLSSController = struct {
    ai_upscaler: *ghostnv.AIUpscaler,
    
    pub const DLSSMode = enum {
        Quality,
        Balanced,
        Performance,
        UltraPerformance,
    };
    
    pub fn enableDLSS(self: *DLSSController, mode: DLSSMode) !void {
        try self.ai_upscaler.setDLSSMode(mode);
    }
    
    pub fn setDLSSSharpening(self: *DLSSController, level: f32) !void {
        // Range: 0.0 to 1.0
        try self.ai_upscaler.setSharpening(level);
    }
    
    pub fn getDLSSStatus(self: *DLSSController) !bool {
        return self.ai_upscaler.isDLSSActive();
    }
};
```

#### 3. Driver Interface Layer
```zig
// Replace current stubs with GhostNV driver calls
const ghostnv = @import("ghostnv");

pub const GPUControl = struct {
    driver: *ghostnv.Driver,
    
    pub fn init() !GPUControl {
        return GPUControl{
            .driver = try ghostnv.Driver.connect(),
        };
    }
    
    pub fn getGPUInfo(self: *GPUControl) !GPUInfo {
        return self.driver.queryGPUInfo();
    }
};
```

#### 2. Display Management Integration
```zig
// Leverage GhostNV's display subsystem
pub const DisplayManager = struct {
    ghostnv_displays: *ghostnv.DisplayController,
    
    pub fn setVibrance(self: *DisplayManager, display_id: u32, level: f32) !void {
        try self.ghostnv_displays.setColorVibrance(display_id, level);
    }
    
    pub fn enableHDR(self: *DisplayManager, display_id: u32) !void {
        try self.ghostnv_displays.setHDRMode(display_id, true);
    }
};
```

#### 4. Ray Tracing Control
```zig
// RT core management via GhostNV
pub const RayTracingController = struct {
    rt_manager: *ghostnv.RayTracingManager,
    
    pub fn enableRayTracing(self: *RayTracingController, application: []const u8) !void {
        try self.rt_manager.setRTEnabled(application, true);
    }
    
    pub fn setRTQuality(self: *RayTracingController, quality: u32) !void {
        // Quality levels: 1-4 (Low, Medium, High, Ultra)
        try self.rt_manager.setQualityLevel(quality);
    }
    
    pub fn getRTCapabilities(self: *RayTracingController) !struct { cores: u32, memory: u64 } {
        return self.rt_manager.getHardwareCapabilities();
    }
};
```

#### 5. Memory Management Control
```zig
// VRAM management and allocation control
pub const MemoryController = struct {
    memory_manager: *ghostnv.VRAMManager,
    
    pub fn getMemoryInfo(self: *MemoryController) !struct { total: u64, used: u64, free: u64 } {
        return self.memory_manager.getMemoryStats();
    }
    
    pub fn setMemoryAllocationStrategy(self: *MemoryController, strategy: enum { Conservative, Aggressive, Balanced }) !void {
        try self.memory_manager.setAllocationStrategy(strategy);
    }
    
    pub fn flushVRAM(self: *MemoryController) !void {
        try self.memory_manager.flush();
    }
};
```

#### 6. Power Management
```zig
// Power state and performance control
pub const PowerController = struct {
    power_manager: *ghostnv.PowerManager,
    
    pub fn setPowerLimit(self: *PowerController, watts: u32) !void {
        try self.power_manager.setPowerLimit(watts);
    }
    
    pub fn getPowerDraw(self: *PowerController) !u32 {
        return self.power_manager.getCurrentPowerDraw();
    }
    
    pub fn setPerformanceMode(self: *PowerController, mode: enum { Optimal, MaxPerformance, PowerSaving }) !void {
        try self.power_manager.setPerformanceMode(mode);
    }
};
```

#### 7. VRR (Variable Refresh Rate) Control
```zig
// Connect to GhostNV's VRR management
pub const VRRController = struct {
    vrr_manager: *ghostnv.VRRManager,
    
    pub fn enableVRR(self: *VRRController, display: u32) !void {
        try self.vrr_manager.enable(display);
    }
    
    pub fn setRefreshRange(self: *VRRController, display: u32, min: u32, max: u32) !void {
        try self.vrr_manager.setRange(display, min, max);
    }
};
```

## Integration Steps

### Phase 1: Core Driver Connection
1. **Establish GhostNV Driver Link**
   - Replace hardware detection stubs
   - Implement real GPU enumeration
   - Connect to driver version reporting

2. **Memory Management Cleanup**
   - Fix existing allocation leak
   - Ensure proper cleanup of GhostNV resources
   - Implement RAII patterns for driver handles

### Phase 2: Display System Integration
1. **Multi-Monitor Support**
   - Query display topology from GhostNV
   - Implement per-display configuration
   - Add display hotplug detection

2. **Color Management**
   - Vibrance control via GhostNV APIs
   - HDR enablement and configuration
   - Color profile management

### Phase 3: Advanced Features
1. **Overclocking Integration**
   - Safe overclocking limits from GhostNV
   - Real-time monitoring and stress testing
   - Profile save/restore functionality

2. **Upscaling Control**
   - DLSS profile management
   - FSR/XeSS configuration
   - Per-game settings storage

## API Mapping

### NVCTL Command → GhostNV API
```
# Core GPU Operations
nvctl --gpu-info        → ghostnv.Driver.queryGPUInfo()
nvctl --memory-info     → ghostnv.VRAMManager.getMemoryStats()
nvctl --power-info      → ghostnv.PowerManager.getCurrentPowerDraw()

# Display Management
nvctl --display-list    → ghostnv.DisplayController.enumerateDisplays()
nvctl --set-vibrance    → ghostnv.DisplayController.setDigitalVibrance()
nvctl --hdr-enable      → ghostnv.DisplayController.setHDRMode()
nvctl --enable-vrr      → ghostnv.VRRManager.enable()

# AI Upscaling & RT
nvctl --dlss-enable     → ghostnv.AIUpscaler.setDLSSMode()
nvctl --dlss-quality    → ghostnv.AIUpscaler.setDLSSMode()
nvctl --dlss-sharpening → ghostnv.AIUpscaler.setSharpening()
nvctl --rt-enable       → ghostnv.RayTracingManager.setRTEnabled()
nvctl --rt-quality      → ghostnv.RayTracingManager.setQualityLevel()

# Performance Control
nvctl --overclock       → ghostnv.OverclockController.setClocks()
nvctl --power-limit     → ghostnv.PowerManager.setPowerLimit()
nvctl --perf-mode       → ghostnv.PowerManager.setPerformanceMode()
nvctl --fan-control     → ghostnv.ThermalController.setFanCurve()
```

## Error Handling Strategy

### GhostNV Error Integration
```zig
pub const NVCTLError = error{
    DriverNotFound,
    GPUNotSupported,
    PermissionDenied,
    DisplayNotConnected,
    OverclockingDisabled,
    GhostNVError,
};

pub fn handleGhostNVError(err: ghostnv.Error) NVCTLError {
    return switch (err) {
        ghostnv.Error.DriverNotLoaded => NVCTLError.DriverNotFound,
        ghostnv.Error.InsufficientPrivileges => NVCTLError.PermissionDenied,
        else => NVCTLError.GhostNVError,
    };
}
```

## Testing Strategy

### Integration Test Plan
1. **Driver Connection Tests**
   - Verify GhostNV driver detection
   - Test graceful fallback when driver unavailable
   - Validate GPU enumeration accuracy

2. **Feature Parity Tests**
   - Compare output with original nvcontrol
   - Verify all commands work with GhostNV backend
   - Test error conditions and recovery

3. **Performance Tests**
   - Measure command execution time
   - Monitor memory usage patterns
   - Validate cleanup on exit

## Migration Path

### Current State → GhostNV Integration
1. **Preserve CLI Interface** - Keep existing command structure
2. **Replace Backend** - Swap stubs for GhostNV calls
3. **Enhance Features** - Add capabilities not possible with stubs
4. **Maintain Compatibility** - Ensure existing scripts continue working

## Dependencies

### Required GhostNV Components
- `ghostnv-driver` - Core driver interface and GPU enumeration
- `ghostnv-display` - Display management, digital vibrance, HDR, VRR
- `ghostnv-ai-upscaler` - DLSS/FSR/XeSS control and configuration  
- `ghostnv-raytracing` - RT core management and quality settings
- `ghostnv-overclock` - GPU/Memory clock control and profiles
- `ghostnv-power` - Power limit and performance mode management
- `ghostnv-memory` - VRAM allocation and monitoring
- `ghostnv-thermal` - Fan curves, temperature monitoring

### Build Integration

#### Adding GhostNV Dependency
```bash
# Fetch and save GhostNV as a dependency
zig fetch --save https://github.com/ghostkellz/ghostnv
```

#### build.zig Configuration
```zig
// build.zig additions
const ghostnv = b.dependency("ghostnv", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("ghostnv", ghostnv.module("ghostnv"));
```

## Missing Components & Gaps

### Critical Missing Elements
1. **Application Profile System** - Per-game DLSS/RT settings storage and retrieval
2. **Compositor Integration** - Deep Wayland/X11 compositor hooks for VRR and HDR
3. **Driver Update Management** - Automatic detection and installation of GhostNV updates
4. **Configuration Persistence** - Settings save/restore across reboots and driver updates
5. **Multi-GPU Support** - SLI/NVLink configuration and load balancing
6. **Monitoring Dashboard** - Real-time telemetry collection and display
7. **Safety Systems** - Temperature protection, power draw limits, stability monitoring

### Advanced Integration Opportunities
1. **Game Launcher Integration** - Automatic profile switching based on running applications
2. **Machine Learning Optimization** - AI-driven performance tuning based on usage patterns
3. **Remote Management** - Network-based GPU control for headless systems
4. **Cloud Integration** - GeForce Experience-like features through GhostNV cloud services

### Implementation Priority Matrix
```
High Priority + High Impact:
- Digital Vibrance Control
- DLSS Integration  
- VRR Management
- Power Monitoring

Medium Priority + Medium Impact:
- Ray Tracing Controls
- Memory Management
- Fan Curve Profiles
- Application Profiles

Lower Priority + Future Enhancement:
- Multi-GPU Support
- Cloud Integration
- ML Optimization
- Remote Management
```

This integration will transform your NVCTL from a feature-complete stub implementation into a fully functional NVIDIA control utility powered by the GhostNV driver infrastructure, with comprehensive coverage of modern GPU features and management capabilities.
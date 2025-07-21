# nvctl Development Status

This is the Zig implementation of nvctl, built using the following dependencies:

## Dependencies
- **ghostnv**: Pure Zig NVIDIA driver implementation
- **jaguar**: GUI framework (similar to egui)  
- **flash**: CLI framework (similar to clap)

## Current Implementation Status

### ✅ Completed Features
- **CLI Framework**: Complete command structure with subcommands
- **GPU Monitoring**: 
  - `nvctl gpu info` - Comprehensive GPU information
  - `nvctl gpu stat` - Live TUI dashboard with real-time stats
  - `nvctl gpu capabilities` - Overclocking capabilities and limits
- **Display Management**:
  - `nvctl display info` - Display information and capabilities
  - `nvctl display ls` - List all connected displays
  - `nvctl display vibrance get/set/reset` - Digital vibrance control
  - `nvctl display hdr status/enable/disable` - HDR management
- **Overclocking Controls**:
  - `nvctl overclock info` - Current overclocking status
  - `nvctl overclock apply` - Apply overclocking settings with safety checks
  - `nvctl overclock reset` - Reset to defaults
  - `nvctl overclock stress-test` - GPU stress testing with monitoring

### 🚧 Placeholder Modules (Future Implementation)
- **VRR Management**: Variable refresh rate control across compositors
- **Upscaling**: DLSS/FSR/XeSS per-game profiles
- **Driver Management**: Package manager integration
- **Fan Control**: Manual fan curves and speed control
- **GUI**: Jaguar-based graphical interface

## Build Instructions

```bash
# Standard build (CLI + GUI)
zig build

# Testing build (headless CI)
zig build -Dtesting=true

# With system tray support
zig build -Dsystem-tray=true

# Release build
zig build -Doptimize=ReleaseFast
```

## Usage Examples

```bash
# GPU monitoring
nvctl gpu info                    # Show GPU details
nvctl gpu stat                    # Live TUI dashboard
nvctl gpu capabilities           # Overclocking limits

# Display management
nvctl display ls                  # List displays
nvctl display vibrance set 150   # Set 150% vibrance
nvctl display hdr status         # Check HDR status

# Overclocking
nvctl overclock info             # Current settings
nvctl overclock apply --gpu-offset 100 --power-limit 110
nvctl overclock stress-test 5    # 5 minute stress test

# Help
nvctl help                       # Show all commands
nvctl gpu help                   # GPU-specific help
```

## Architecture

The application uses a modular design with separate modules for each major feature:

- `src/main.zig` - CLI parsing and dispatch
- `src/gpu.zig` - GPU monitoring and information  
- `src/display.zig` - Display and vibrance management
- `src/overclocking.zig` - Overclocking controls and stress testing
- `src/gui.zig` - GUI interface (placeholder)
- `src/[feature].zig` - Individual feature modules

All modules use the ghostnv driver for direct hardware communication, providing better performance and reliability than external dependencies.
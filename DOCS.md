# nvcontrol Documentation

## Overview

nvc#### **Core Technologies**
- **Zig**: Systems programming language with compile-time safety and C interop
- **NVML**: Direct NVIDIA driver integration for hardware monitoring
- **Native GUI**: Cross-platform GUI framework optimized for performance
- **Zig Build System**: Advanced build system with dependency management

#### **Linux Integration** 
- **DBUS**: Desktop environment integration
- **systemd**: Service management and startup integration
- **sysfs**: Direct hardware access for advanced features
- **Wayland Protocols**: Native compositor communicationern, feature-rich NVIDIA GPU management tool designed specifically for Linux and Wayland environments. Unlike traditional tools that were designed for Windows and ported to Linux, nvcontrol is built from the ground up for the Linux ecosystem using Zig.

## Core Philosophy

### **Linux-Native Design**
- **Package Manager Integration**: Seamless installation through system package managers
- **Systemd Integration**: Proper service management and startup integration  
- **Desktop Integration**: Follows XDG standards with proper .desktop files
- **Shell Integration**: Comprehensive shell completions for power users

### **Wayland-First Architecture**
- **No X11 Dependencies**: Core functionality works entirely on Wayland
- **Compositor-Specific Optimizations**: Custom implementations for KDE, GNOME, Hyprland, Sway
- **Future-Proof Design**: Ready for the post-X11 Linux desktop

## Architecture

### **Modular Design**

```
nvcontrol/
├── src/lib.zig             # Core library with error types
├── src/gpu.zig             # GPU monitoring and driver integration
├── src/overclocking.zig    # Advanced overclocking with safety
├── src/vrr.zig             # VRR management across compositors  
├── src/upscaling.zig       # DLSS/FSR/XeSS per-game profiles
├── src/fan.zig             # Fan control with driver integration
├── src/drivers.zig         # Package manager integration
├── src/display.zig         # Display detection and HDR
├── src/vibrance.zig        # Digital vibrance implementation
├── src/power.zig           # GPU power management and profiles
├── src/theme.zig           # Modern UI themes
└── src/main.zig            # Unified CLI/GUI application
```

### **Technology Stack**

#### **Core Technologies**
- **zig**: Memory-safe systems programming with excellent performance in zig dev v0.15+ 
- **NVML**: Direct NVIDIA driver integration for hardware monitoring
- **eframe/egui**: Modern immediate-mode GUI framework
- **clap**: Advanced CLI argument parsing with shell completions

#### **Linux Integration** 
- **DBUS**: Desktop environment integration
- **systemd**: Service management and startup integration
- **sysfs**: Direct hardware access for advanced features
- **Wayland Protocols**: Native compositor communication

## Features Deep Dive

### **1. GPU Monitoring & Management**

#### **Real-Time Stats**
```zig
// NVML integration for live GPU data
const nvml = try nvml_init();
defer nvml_shutdown(&nvml);

const device = try nvml_device_by_index(&nvml, 0);
const temp = try nvml_device_temperature(&device, .gpu);
const power = try nvml_device_power_usage(&device);
const util = try nvml_device_utilization_rates(&device);
const mem_info = try nvml_device_memory_info(&device);
```

#### **TUI Dashboard**
- Live updating terminal interface with charts
- Color-coded temperature warnings
- Real-time VRAM usage tracking
- Fan speed monitoring with RPM display

### **2. Advanced Overclocking**

#### **Safety-First Approach**
```zig
pub const OverclockProfile = struct {
    gpu_clock_offset: i32,     // MHz offset from base
    memory_clock_offset: i32,  // MHz offset from base  
    power_limit: u8,           // Percentage (50-120%)
    temp_limit: u8,            // Temperature limit in Celsius
    fan_curve: []const FanCurvePoint,  // (temp, fan_speed) pairs
};

pub const FanCurvePoint = struct {
    temp: u8,
    fan_speed: u8,
};
```

#### **Multi-Method Application**
- **X11**: nvidia-settings integration for traditional setups
- **Wayland**: Direct sysfs manipulation with proper permissions
- **Validation**: Hardware capability detection and limit enforcement

#### **Stress Testing**
- Integration with popular stress testing tools (glmark2, furmark, vkmark)
- Automatic temperature monitoring during tests
- Stability validation with automated rollback

### **3. VRR (Variable Refresh Rate) Management**

#### **Universal Compositor Support**
```zig
pub fn apply_vrr_settings(display_name: []const u8, settings: *const VrrSettings) NvResult!void {
    const desktop = std.process.getEnvVarOwned(allocator, "XDG_CURRENT_DESKTOP") catch return error.DesktopNotFound;
    defer allocator.free(desktop);
    
    if (std.mem.eql(u8, desktop, "KDE")) {
        try apply_vrr_kde(display_name, settings);
    } else if (std.mem.eql(u8, desktop, "GNOME")) {
        try apply_vrr_gnome(settings);
    } else if (std.mem.eql(u8, desktop, "Hyprland")) {
        try apply_vrr_hyprland(display_name, settings);
    } else if (std.mem.eql(u8, desktop, "sway")) {
        try apply_vrr_sway(display_name, settings);
    } else {
        try apply_vrr_x11(display_name, settings);
    }
}
```

#### **Per-Application Profiles**
- Game-specific VRR settings that auto-apply
- Competitive gaming presets (high refresh, low latency)
- Single-player presets (quality over performance)
- Browser/desktop presets (power saving)

### **4. Upscaling Technology Management**

#### **Multi-Technology Support**
```zig
pub const UpscalingTechnology = enum {
    DLSS,    // NVIDIA RTX series
    FSR,     // AMD/Universal  
    XeSS,    // Intel Arc
    Native,  // No upscaling
};
```

#### **Game Integration Methods**
- **Configuration Files**: Direct modification of game config files
- **Environment Variables**: Runtime environment setup for supported games
- **Registry Manipulation**: Wine/Proton game compatibility
- **Auto-Detection**: Process monitoring for automatic profile application

### **5. Fan Control System**

#### **Multi-Layer Approach**
```zig
pub fn set_fan_speed(fan_id: usize, speed_percent: u8) NvResult!void {
    // Try NVML first (enterprise drivers)
    if (nvml_init()) |nvml| {
        defer nvml_shutdown(&nvml);
        return nvml_set_fan_speed(&nvml, fan_id, speed_percent);
    } else |_| {}
    
    // Try nvidia-settings (X11)
    if (std.process.getEnvVarOwned(allocator, "DISPLAY")) |display| {
        defer allocator.free(display);
        return set_fan_speed_nvidia_settings(fan_id, speed_percent);
    } else |_| {}
    
    // Try direct sysfs manipulation (requires root)
    return set_fan_speed_sysfs(fan_id, speed_percent);
}
```

#### **Hardware Abstraction**
- Automatic detection of controllable fans
- Safety limits based on hardware capabilities
- Temperature-based automatic curves
- Manual override with safety warnings

### **6. Driver Management**

#### **Package Manager Integration**
```bash
# Arch Linux
nvcontrol drivers install proprietary  # Uses pacman
nvcontrol drivers install open         # nvidia-open package

# Ubuntu/Debian  
nvcontrol drivers install proprietary  # Uses apt with proper PPA
nvcontrol drivers install open         # nvidia-kernel-open-dkms

# Fedora
nvcontrol drivers install proprietary  # Uses dnf with RPM Fusion
```

#### **DKMS Management**
- Automatic DKMS module building and installation
- Conflict resolution between driver types
- Kernel update compatibility checking
- Rollback support for failed installations

## GUI Application

### **Modern UI Design**

#### **Theme System**
```zig
pub const ModernTheme = struct {
    primary: []const u8,      // Bright cyan for NVIDIA branding
    secondary: []const u8,    // Orange accent for highlights
    background: []const u8,   // Deep black background  
    surface: []const u8,      // Dark gray for cards/panels
    glass_alpha: f32,         // Glass morphism transparency
};
```

#### **Component Architecture**
- **Tab-based Navigation**: GPU, Display, Overclock, Fan, Settings
- **Real-time Updates**: Live data refresh with configurable intervals
- **Safety Warnings**: Color-coded alerts for dangerous operations
- **Quick Actions**: One-click presets for common operations

### **Responsive Design**
- **Minimum Window Size**: 800x500 for usability
- **Scalable UI Elements**: Works on HiDPI displays
- **Keyboard Navigation**: Full accessibility support
- **Touch Support**: Ready for touchscreen Linux devices

## CLI Tools

### **Command Structure**
```bash
nvcontrol <command> [options]

# CLI Examples
nvcontrol gpu stat                    # Live monitoring
nvcontrol overclock apply --gpu-offset 150
nvcontrol vrr enable DP-1
nvcontrol upscaling enable cyberpunk2077 --tech dlss
nvcontrol drivers install open

# GUI Mode
nvcontrol                            # Launch GUI (default when no args)
nvcontrol --gui                      # Explicitly launch GUI
```

### **Shell Integration**
- **Completions**: Bash, Zsh, Fish support with context-aware suggestions
- **Man Pages**: Comprehensive documentation integration
- **Exit Codes**: Proper error handling for scripting
- **JSON Output**: Machine-readable output for integration

## Configuration

### **Config File Locations**
```
~/.config/nvcontrol/config.toml    # User settings
~/.config/nvcontrol/profiles/      # Saved profiles
~/.config/nvcontrol/themes/        # Custom themes
```

### **Profile System**
```toml
[default_profile]
gpu_offset = 0
memory_offset = 0
power_limit = 100
fan_curve = [[30, 20], [70, 70], [85, 100]]

[gaming_profile]  
gpu_offset = 150
memory_offset = 800
power_limit = 115
```

## Safety & Security

### **Permission Model**
- **Minimum Privileges**: Only request necessary permissions
- **Capability Detection**: Graceful degradation when features unavailable
- **User Confirmation**: Dangerous operations require explicit confirmation
- **Logging**: Comprehensive operation logging for debugging

### **Hardware Protection**
- **Temperature Monitoring**: Automatic shutdown on overheat
- **Power Limiting**: Respect hardware power delivery limits
- **Voltage Protection**: No unsafe voltage modifications
- **Rollback Capability**: Automatic revert on system instability

## Development

### **Building**
```bash
# Debug build
zig build

# Release build  
zig build -Doptimize=ReleaseFast

# With system tray
zig build -Dsystem-tray=true

# Testing build (for CI runners)
zig build -Dtesting=true
```

### **Testing**
```bash
# Unit tests
zig build test

# Integration tests
zig build test --summary all

# CLI testing
./test_no_tray.sh
```

### **Code Standards**
- **Zig v0.15.0+**: Latest stable Zig version with modern features
- **zig fmt**: Consistent code formatting and style
- **Testing**: Comprehensive unit and integration tests
- **Documentation**: Inline documentation and comments

## Installation

### **Zig Package Manager**
```bash
# Add nvcontrol as a dependency in build.zig.zon
zig fetch --save https://github.com/ghostkellz/nvcontrol

# Then in build.zig:
const nvcontrol = b.dependency("nvcontrol", .{});
exe.root_module.addImport("nvcontrol", nvcontrol.module("nvcontrol"));
```

## Troubleshooting

### **Common Issues**

#### **NVML Not Available**
```bash
# Check driver installation
nvidia-smi
lsmod | grep nvidia

# Install proper drivers
nvcontrol drivers install proprietary
```

#### **Fan Control Not Working**
```bash
# Check permissions
ls -la /sys/class/hwmon/

# Try with elevated privileges
sudo nvcontrol fan set 0 50
```

#### **VRR Not Available**
```bash
# Check compositor support
echo $XDG_CURRENT_DESKTOP

# Enable experimental features (GNOME)
gsettings set org.gnome.mutter experimental-features "['variable-refresh-rate']"
```

### **Debug Mode**
```bash
# Enable verbose logging
nvcontrol gpu stat --verbose

# GUI debug mode
nvcontrol --debug
```

## Contributing

### **Development Environment**
- **Zig v0.15.0+**: Required toolchain
- **NVIDIA GPU**: For hardware testing
- **Linux Desktop**: Wayland preferred for testing
- **Multiple Distros**: Test across package managers

### **Code Organization**
- **Feature Branches**: Separate branches for major features
- **Modular Design**: Keep modules independent and testable
- **Documentation**: Update docs with code changes
- **Testing**: Include tests for new functionality

For more information, see [BUILDING.md](BUILDING.md) and [COMMANDS.md](COMMANDS.md).

nvcontrol is a modern, full-featured NVIDIA settings manager for Linux, designed for Wayland compositors (KDE, GNOME, Hyprland, Sway, etc.) and NVIDIA open drivers (>= 570). It provides both CLI and GUI functionality in a single unified application for controlling GPU, display, color, and fan settings.

## Build Features

nvcontrol uses Zig build options to provide flexible builds:

- **`-Dsystem-tray=true`** - Enables system tray integration
- **Default** - Full application with CLI and GUI

### Build Examples
```sh
# Full build (CLI + GUI + tray)
zig build -Dsystem-tray=true

# Standard build (CLI + GUI, no tray)
zig build

# Release build for distribution
zig build -Doptimize=ReleaseFast -Dsystem-tray=true

# Testing build (for CI runners without GUI dependencies)
zig build -Dtesting=true
```

---

## Deployment & CI

### Continuous Integration
The project uses GitHub Actions with two workflows:

- **CI** (`ci.yml`) - Runs on every push/PR, builds with `-Dtesting=true` to avoid GUI dependencies in headless environments
- **Release** (`release.yml`) - Runs on tags, builds with full features on self-hosted runner with complete GUI support

### Self-Hosted Runner Requirements
The release workflow runs on `nv-palladium` with:
- NVIDIA GPU and drivers
- Full desktop environment 
- GTK3/GLib development libraries
- System tray support
- **Wayland** (KDE Plasma 6+, GNOME, Hyprland, Sway, etc.)
- **NVIDIA Open Drivers** (>= 570, required for most features)
- **X11** (legacy support, some features may be limited)

---

## Key Features
- Per-display digital vibrance control (native Zig implementation)
- Real-time GPU monitoring (TUI and GUI)
- Fan speed monitoring and (planned) control
- ICC profile management and HDR toggle (stub)
- Profiles and automation (planned)

---

## Wayland + KDE Notes
- **Wayland is the primary target.**
- KDE Plasma 6+ is recommended for best HDR and color management support.
- Some features (e.g., vibrance, gamma, HDR) may require recent NVIDIA drivers and kernel parameters (e.g., `nvidia_drm.modeset=1`).
- nVibrant is required for digital vibrance on Wayland (see [nVibrant](https://github.com/Tremeschin/nVibrant)).

---

## Usage Examples

- Launch the GUI:
  ```sh
  nvcontrol
  ```
- Show GPU info:
  ```sh
  nvcontrol gpu info
  ```
- Live GPU stats (TUI):
  ```sh
  nvcontrol gpu stat
  ```
- List displays:
  ```sh
  nvcontrol display ls
  ```
- Set vibrance:
  ```sh
  nvcontrol display vibrance 512 1023
  ```

---

## System Dependencies

### Runtime Dependencies
- `nvcontrol`: No additional dependencies beyond standard system libraries
- System tray support (optional): Desktop environment with system tray support
- Digital vibrance: Native Zig implementation

### Build Dependencies
```sh
# Ubuntu/Debian (for full builds)
sudo apt-get install libgtk-3-dev libglib2.0-dev libgdk-pixbuf2.0-dev \
  libpango1.0-dev libatk1.0-dev libcairo2-dev pkg-config build-essential

# Testing build (for CI runners)
sudo apt-get install pkg-config build-essential
```

### Distribution Support
- **Arch Linux**: AUR package (planned)
- **Ubuntu/Debian**: Manual build or download releases
- **Flatpak**: Planned
- **Self-hosted runners**: Full GUI support on nv-palladium

---

## Troubleshooting
- If vibrance does not work, ensure nVibrant is installed and in your PATH.
- For HDR, ensure you are running KDE Plasma 6+ and have a compatible monitor and driver.
- Some features may require running as root or with specific permissions.

### Build Issues
- **GUI dependencies missing**: Install required dependencies for full builds
- **System tray errors**: Build without `-Dsystem-tray=true`
- **Headless CI environments**: Use `-Dtesting=true` in automation

### Runtime Issues
- **Permissions**: Some features may require elevated permissions
- **Missing dependencies**: Ensure all runtime dependencies are installed

---

## Roadmap
- Full fan control (curves, manual override)
- Advanced display management (resolution, refresh, orientation)
- Profile save/load and automation
- System tray widget
- More robust error handling and notifications

---

For CLI command details, see COMMANDS.md.

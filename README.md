# nvcontrol

<div align="center">
  <img src="assets/icons/nvctl_logo.png" alt="nvcontrol Logo" width="128" height="128">
  
  **Modern NVIDIA Settings Manager for Linux + Wayland**
  
  A feature-rich, native Linux application for NVIDIA GPU management with full Wayland support, advanced overclocking, VRR control, and DLSS/FSR management.
  
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)
![Platform](https://img.shields.io/badge/Platform-Linux-green)
![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)
![NVIDIA](https://img.shields.io/badge/NVIDIA-76B900?logo=nvidia&logoColor=white)
![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig&logoColor=black)
![Zig Version](https://img.shields.io/badge/Zig-v0.15.0-orange?logo=zig)
</div>

## ✨ Features

### 🎮 **GPU Management**
- **Real-time monitoring** with live temperature, power, VRAM usage
- **Advanced overclocking** with safety limits and stress testing
- **Memory timing editor** for enthusiasts
- **Power management** with Performance/Balanced/PowerSaver profiles
- **Power monitoring** with real-time draw, limits, and thermal data

### 🖥️ **Display & VRR**
- **Smart VRR management** across all major Wayland compositors
- **Per-application VRR settings** for optimal gaming
- **HDR toggle** with proper color space handling
- **Digital vibrance** control with integrated nvibrant for enhanced visuals

### ⚡ **Upscaling Technologies**
- **DLSS/FSR/XeSS toggle** with per-game profiles
- **Automatic game detection** and profile application
- **Quality presets** (Performance, Balanced, Quality, Ultra)
- **Configuration file modification** for deep integration

### 🌀 **Fan Control**
- **Real-time fan monitoring** with RPM and percentage display
- **Manual fan speed control** (where supported)
- **Quick presets** (Quiet, Auto, Max)
- **Custom fan curves** (coming soon)

### 🚀 **Driver Management**
- **Package manager integration** (Arch, Ubuntu, Fedora)
- **Driver installation**: `nvctl drivers install proprietary/open/open-beta`
- **DKMS issue resolution** with automatic repair
- **Shell completions** for Bash, Zsh, Fish

## 🏗️ **Modern Architecture**

### **Wayland-Native**
- Full support for KDE, GNOME, Hyprland, Sway
- Direct compositor integration for VRR control
- No X11 dependencies for core functionality

### **Beautiful UI**
- **Glass morphism design** with NVIDIA-inspired themes
- **Dark/Light/Gaming** theme variants
- **Live GPU stats** with real-time graphs
- **Intuitive controls** with safety warnings

### **CLI Power Tools**
```bash
# GPU monitoring
nvctl gpu stat                    # Live TUI dashboard
nvctl gpu capabilities           # Show overclocking limits

# VRR management  
nvctl vrr enable DP-1            # Enable for specific display
nvctl vrr configure DP-1 --min-refresh 48 --max-refresh 144

# Upscaling control
nvctl upscaling enable cyberpunk2077 --tech dlss --quality balanced
nvctl upscaling auto-detect      # Find running games

# Overclocking
nvctl overclock apply --gpu-offset 150 --memory-offset 800 --power-limit 115
nvctl overclock stress-test 10   # 10-minute stability test

# Driver management
nvctl drivers install open       # Install open-source drivers
nvctl drivers status            # Check current driver info
```

## 🎯 **What Makes nvcontrol Special**

### **Linux-First Design**
Unlike Windows tools ported to Linux, nvcontrol is built ground-up for Linux:
- **Package manager integration** instead of manual downloads
- **Systemd integration** for automatic startup
- **Proper desktop file** with correct categories and icons
- **Shell completion** for power users

### **Wayland Excellence** 
- **No X11 fallbacks** - true Wayland-native operation
- **Per-compositor optimization** (KDE vs GNOME vs Hyprland)
- **Future-proof architecture** ready for post-X11 world

### **Advanced Features**
- **Per-game profiles** that auto-apply when games launch
- **Thermal management** with predictive algorithms
- **Smart defaults** that learn from user behavior
- **Enterprise features** for multi-GPU setups

## 🚀 **Quick Start**

### **Prerequisites**
For full functionality, especially digital vibrance control:
```bash
# Python 3.9+ and pip/uv for nvibrant integration
sudo apt install python3 python3-pip  # Ubuntu/Debian
# OR
sudo pacman -S python python-pip      # Arch
# OR  
sudo dnf install python3 python3-pip  # Fedora

# nvibrant will be automatically installed during build
```

### **GUI Application**
```bash
# Install and run GUI
zig build -Doptimize=ReleaseFast -Dgui=true
./zig-out/bin/nvcontrol
```

### **CLI Tools** 
```bash
# Install shell completions
./scripts/install-completions.sh

# Basic usage
nvctl gpu info                   # GPU information
nvctl display vibrance 800 600  # Set vibrance
nvctl fan info                   # Fan status
```

### **Installation**
```bash
# Arch Linux (AUR)
yay -S nvcontrol-git

# Ubuntu/Debian
sudo dpkg -i nvcontrol_0.1.0_amd64.deb

# Fedora
sudo rpm -i nvcontrol-0.1.0.x86_64.rpm

# From source
git clone https://github.com/ghostkellz/nvcontrol
cd nvcontrol
zig build -Doptimize=ReleaseFast
```

## 📚 **Documentation**

- [**COMMANDS.md**](COMMANDS.md) - Complete CLI reference
- [**DOCS.md**](DOCS.md) - Technical documentation  
- [**BUILDING.md**](BUILDING.md) - Build instructions

## 🎨 **Screenshots**

### Modern GUI
The application features a beautiful, modern interface with:
- **Real-time GPU monitoring** with live charts
- **Advanced overclocking controls** with safety warnings
- **VRR management** across all displays
- **Theme selection** (NVIDIA Dark, Light, Gaming)

### TUI Dashboard
```
┌─ GPU Stats ─────────────────────────────────────┐
│ 🎯 RTX 4090          🌡️ 72°C    ⚡ 380W        │
│ 📈 GPU: ████████░░ 85%   💾 VRAM: 18.2/24.0 GB │
│ 🌀 Fan: ██████░░░░ 65%   🔥 Temp: ████████░░    │
└─────────────────────────────────────────────────┘
```

## 🛣️ **Roadmap**

### **v0.2.0 - Enhanced Gaming**
- [ ] Gamescope integration
- [ ] Shader cache management  
- [ ] Latency optimization tools
- [ ] RGB lighting control

### **v0.3.0 - Enterprise Features**
- [ ] Multi-GPU management
- [ ] Remote monitoring
- [ ] Team management tools
- [ ] Performance analytics

### **v1.0.0 - Production Ready**
- [ ] Stable API
- [ ] Plugin system
- [ ] Marketplace integration
- [ ] Enterprise support

## 🤝 **Contributing**

nvcontrol is open source and welcomes contributions! See our contributing guidelines for details on:
- Code style and standards
- Testing requirements  
- Documentation updates
- Feature proposals

## 📄 **License**

MIT License - see [LICENSE](LICENSE) for details.

Copyright (c) 2025 CK Technology LLC

---

[![Wayland Support](https://img.shields.io/badge/Wayland-Ready-brightgreen?logo=wayland)](https://wayland.freedesktop.org/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-Supported-brightgreen?logo=nvidia)](https://nvidia.com)
[![CLI & GUI](https://img.shields.io/badge/CLI_%2B_GUI-Full_Featured-blueviolet)](#features)
[![nvibrance Integration](https://img.shields.io/badge/nvibrance-Integrated-ff69b4)](https://github.com/Tremeschin/nVibrant)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/ghostkellz/nvcontrol/ci.yml?branch=main)](https://github.com/ghostkellz/nvcontrol/actions)

---

## The Missing NVIDIA Control Panel for Linux + Wayland

**nvcontrol** is a modern, fully featured NVIDIA settings manager for Linux.  
Think: _NVIDIA Control Panel & GeForce Experience, but for Linux + Wayland_.  
No more missing options. No more hacky workarounds. No more nvidia-settings being years behind.

- **Wayland native:** Full support for Wayland compositors (KDE, GNOME, Hyprland, Sway, etc.)
- **Legacy X11 compatible:** Works wherever NVIDIA is available.

---

## Features

- 🖥️ **Full GPU Control**  
  - Clock speeds, power limits, overclocking, undervolting
  - Memory timings, fan curves, temp/power monitoring
  - 🎛️ **Display & Color Management**
  - Per-display resolution, refresh rate, orientation, rotation
  - Digital Vibrance, color profiles, gamma control (via integrated [nVibrant](https://github.com/Tremeschin/nVibrant))
  - HDR toggling and fine-tuning (where supported)
  - Hotplug/multi-monitor configuration with persistent profiles

- 🔊 **Performance & Monitoring**
  - Real-time stats: GPU/VRAM usage, temps, wattage, per-process utilization
  - System tray widget for live monitoring and quick toggles
  - Advanced logging & export (JSON/CSV)

- 🌡️ **Fan & Thermal Control**
  - Custom fan curves, manual overrides, and auto-fan settings
  - Overheat protection, alerts, and fail-safe triggers

- 🖱️ **Input & Latency Tweaks**
  - Low-latency and frame pacing controls for gaming
  - Adjustable frame limiter, VRR/G-SYNC toggle, V-Sync, and more
  - VR/AR optimizations (if available)

- 🧩 **Profiles & Automation**
  - Game/app-specific profiles (auto-load settings per-app)

---

## Installation

### Pre-built Binaries
Download prebuilt binaries from the [Releases](https://github.com/ghostkellz/nvcontrol/releases) page.

### From Source
```sh
# Full installation with GUI and system tray
zig build -Doptimize=ReleaseFast -Dgui=true -Dsystem-tray=true

# CLI only (no GUI dependencies)
zig build -Doptimize=ReleaseFast

# GUI without system tray
zig build -Doptimize=ReleaseFast -Dgui=true
```

### Build Options
- `-Dgui=true -Dsystem-tray=true` - Full GUI with system tray support (default for releases)
- `-Dgui=true` - GUI without system tray
- Default build - CLI only, minimal dependencies

### Requirements

- NVIDIA GPU with nvidia open drivers (570+) at least during testing
- Wayland compositor (KDE, GNOME, Hyprland, Sway, etc.)
- Zig v0.15.0+ (for building from source)

### Optional Dependencies
- **GUI features**: GTK3, GLib (automatically handled by package managers)
- **System tray**: Desktop environment with system tray support
- **Digital vibrance**: [nVibrant](https://github.com/Tremeschin/nVibrant) for Wayland
- **AUR**: TBD

---

## Usage

### CLI

```sh
nvctl --help
```

### GUI

Launch via your application launcher or run:

```sh
# Full GUI (requires -Dgui=true during build)
nvcontrol
```

If built without GUI features, nvcontrol will display an error message.

---

## Roadmap

- [ ] Full support for all NVIDIA GPUs (Turing, Ampere, Ada, etc.)
- [ ] Flatpak & AUR packaging
- [ ] Profile system with save/load functionality
- [ ] System tray widget for quick access
- [ ] Advanced display management (resolution, refresh rate, orientation)
- [ ] Custom fan curves and thermal management
- [ ] Real-time notifications and alerts

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

For detailed build instructions, see [BUILDING.md](BUILDING.md).

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- [nVibrant](https://github.com/Tremeschin/nVibrant) for Digital Vibrance integration
- [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) and the Wayland community
- All contributors and testers


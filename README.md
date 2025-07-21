# nvctl

<div align="center">
  
  **Pure Zig NVIDIA GPU Control Utility**
  
  A modern, high-performance NVIDIA GPU control tool built with Zig, featuring the ghostnv pure Zig driver and comprehensive Wayland support.
  
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)
![Platform](https://img.shields.io/badge/Platform-Linux-green)
![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)
![NVIDIA](https://img.shields.io/badge/NVIDIA-76B900?logo=nvidia&logoColor=white)
![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-f7a41d?logo=zig&logoColor=black)
![Zig Version](https://img.shields.io/badge/Zig-v0.15.0-orange?logo=zig)
</div>

## ✨ Features

### 🎮 **GPU Management**
- **Real-time monitoring** with advanced TUI dashboard powered by phantom
- **Professional overclocking** with safety validation and stress testing
- **Multi-GPU support** for enthusiast and professional setups
- **Comprehensive hardware control** via ghostnv driver integration
- **Thermal management** with predictive algorithms and safety limits

### 🖥️ **Display & Gaming**
- **Smart VRR management** for all major Wayland compositors (KDE, GNOME, Hyprland, Sway)
- **Gamescope integration** for optimized gaming experiences
- **Per-game profiles** with automatic detection and switching
- **HDR control** with proper color space handling
- **Digital vibrance** with integrated controls

### ⚡ **Advanced Features**
- **DLSS/FSR/XeSS control** with quality presets and per-game settings
- **Custom fan curves** with temperature-based automation
- **Power management** with efficiency and performance profiles
- **Driver management** with cross-distribution package manager integration
- **Comprehensive error handling** with graceful degradation

### 🌀 **Modern Architecture**
- **Pure Zig implementation** for maximum performance and safety
- **ghostnv driver** - Pure Zig NVIDIA open driver (575.0.0-ghost)
- **phantom TUI framework** - Professional terminal interface
- **flash CLI framework** - Robust command-line parsing
- **Wayland-native** with no X11 dependencies

## 🚀 **Quick Start**

### **Installation (Arch Linux)**
```bash
# Install from AUR
yay -S nvctl-git

# Or build from source
git clone https://github.com/ghostkellz/nvctl
cd nvctl
zig build -Doptimize=ReleaseSafe
sudo cp zig-out/bin/nvctl /usr/bin/
```

### **Basic Usage**
```bash
# GPU information and monitoring
nvctl gpu info                    # Show GPU details
nvctl gpu stat                    # Live TUI dashboard

# Display and VRR management  
nvctl display list                # List all displays
nvctl vrr enable DP-1             # Enable VRR for display
nvctl vrr status                  # Check VRR status

# Overclocking and performance
nvctl overclock status            # Show current overclocks
nvctl overclock apply --gpu +150 --memory +500 --power 110
nvctl overclock stress-test 10    # 10-minute stability test

# Fan control
nvctl fan status                  # Show fan information
nvctl fan set 75                  # Set all fans to 75%
nvctl fan profile performance    # Apply performance profile

# Gaming integration
nvctl gamescope status            # Check Gamescope session
nvctl gamescope monitor           # Auto-apply game profiles

# Driver management
nvctl drivers status              # Check driver status
nvctl drivers list                # List available drivers
nvctl drivers update              # Update to latest driver
```

## 🎯 **What Makes nvctl Special**

### **Pure Zig Performance**
- **Memory safety** without garbage collection overhead
- **Compile-time optimizations** for maximum efficiency
- **Zero-cost abstractions** with predictable performance
- **Native Linux integration** built from the ground up

### **ghostnv Driver Integration** 
- **Pure Zig NVIDIA driver** (575.0.0-ghost)
- **Direct hardware access** without proprietary binary blobs
- **Open source transparency** with full code auditing
- **Future-proof architecture** for long-term maintenance

### **Advanced Wayland Support**
- **Native Wayland protocols** for VRR and display management
- **Compositor-specific optimizations** (KDE vs GNOME vs Hyprland)
- **No X11 fallbacks** - true Wayland-first design
- **Modern gaming support** with Gamescope integration

### **Professional Features**
- **Multi-GPU management** for professional workstations
- **Enterprise-grade error handling** with comprehensive logging
- **Automated profile switching** based on running applications
- **Thermal protection** with predictive overheating prevention
- **Cross-distribution packaging** (Arch, Ubuntu, Fedora, openSUSE)

## 🏗️ **Architecture Overview**

### **Core Components**
```
nvctl
├── ghostnv_integration.zig    # Hardware abstraction layer
├── gpu.zig                    # GPU monitoring and TUI dashboard
├── display.zig                # Display and VRR management
├── overclocking.zig           # Overclocking and power control
├── fan.zig                    # Fan control and thermal management
├── drivers.zig                # Driver installation and updates
├── gamescope.zig              # Gaming compositor integration
└── main.zig                   # CLI interface and routing
```

### **Dependencies**
- **ghostnv**: Pure Zig NVIDIA driver (575.0.0-ghost)
- **phantom**: TUI framework for rich terminal interfaces
- **flash**: CLI argument parsing and command routing
- **Standard Zig library**: Core functionality and system interfaces

## 📚 **Documentation**

- [**COMMANDS.md**](COMMANDS.md) - Complete CLI reference with examples
- [**DEVELOPMENT.md**](DEVELOPMENT.md) - Developer guide and architecture
- [**DEPENDENCIES.md**](DEPENDENCIES.md) - Dependency documentation
- [**CHANGELOG.md**](CHANGELOG.md) - Version history and changes

## 🎨 **TUI Dashboard Preview**

### Live GPU Monitoring
```
🎯 NVIDIA GPU Dashboard - Live Monitoring
══════════════════════════════════════════════════════════════════════════════════

🎮 GPU: RTX 4090
📦 Driver: 575.0.0-ghost (ghostnv)

🌡️  Temperature:  72°C  [████████████░░░]
📈 Utilization:  85%    [████████████░░░]
⚡ Power Usage:  380W   [███████████████]

📊 Temperature Trend (last 20 samples):
   ▄▅▆▇█▆▅▄▃▄▅▆▇█▆▅▄▃▂▁

📊 Utilization Trend (last 20 samples):
   ▃▄▅▆▇█▆▅▄▃▄▅▆▇█▆▅▄▃▄

⏱️  Uptime: 120s | Refresh #61/∞ | Next: 2s
─────────────────────────────────────────────────────────────────────────────────
Press Ctrl+C to exit | 🔧 Advanced phantom TUI coming soon!
```

## 🛠️ **Building from Source**

### **Prerequisites**
```bash
# Install Zig 0.15.0+
curl https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz | tar -xJ
export PATH=\"$PATH:$(pwd)/zig-linux-x86_64-0.15.0\"

# Clone with submodules
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl
```

### **Build Options**
```bash
# Release build (recommended)
zig build -Doptimize=ReleaseSafe

# Debug build with testing
zig build -Doptimize=Debug -Dtesting=true

# System tray integration (future)
zig build -Dsystem-tray=true

# Run tests
zig build test
```

### **Development Setup**
```bash
# Install development dependencies
sudo pacman -S nvidia nvidia-utils gdb valgrind  # Arch
sudo apt install nvidia-driver-535 gdb valgrind  # Ubuntu

# Set up git hooks
./scripts/setup-dev.sh

# Run development build
zig build run -- gpu info
```

## 🎯 **Roadmap**

### **v0.2.0 - Enhanced Hardware Support**
- [ ] Complete ghostnv driver API integration
- [ ] Multi-GPU enumeration and control
- [ ] Advanced fan curve editor with phantom TUI
- [ ] Memory timing optimization tools
- [ ] Hardware validation and burn-in testing

### **v0.3.0 - Gaming Excellence**
- [ ] Steam integration for automatic game detection
- [ ] Gamescope HDR and upscaling optimization
- [ ] Per-game shader cache management  
- [ ] Latency analyzer and optimization tools
- [ ] RGB lighting control integration

### **v1.0.0 - Production Ready**
- [ ] Stable API with backward compatibility
- [ ] Complete phantom TUI dashboard
- [ ] Enterprise monitoring and alerting
- [ ] Plugin system for extensibility
- [ ] Full cross-distribution packaging

## 🤝 **Contributing**

nvctl is open source and welcomes contributions! We follow the Zig community standards:

### **Development Guidelines**
- **Code style**: Follow `zig fmt` formatting
- **Testing**: All features must have tests
- **Documentation**: Public APIs require doc comments
- **Safety**: Memory safety is paramount - no undefined behavior

### **Getting Started**
```bash
# Fork the repository
git fork https://github.com/ghostkellz/nvctl

# Create feature branch
git checkout -b feature/my-feature

# Make changes and test
zig build test
zig build run -- gpu info

# Submit pull request
git push origin feature/my-feature
```

## 🐛 **Bug Reports**

Found a bug? Please report it with:
- **System info**: Distribution, kernel version, NVIDIA driver version
- **nvctl version**: Output of `nvctl --version`
- **Steps to reproduce**: Detailed reproduction steps
- **Expected vs actual**: What should happen vs what does happen
- **Logs**: Run with `NVCTL_LOG_LEVEL=debug nvctl <command>`

## 📄 **License**

MIT License - see [LICENSE](LICENSE) for details.

**Copyright (c) 2025 Christopher Kelley <ckelley@ghostkellz.sh>**

---

## 🙏 **Acknowledgments**

- **NVIDIA Corporation** - For hardware specifications and driver documentation
- **Zig Programming Language** - For the excellent systems programming language
- **Wayland Project** - For the modern display server protocol
- **Linux Community** - For the open source ecosystem that makes this possible
- **Beta Testers** - For helping identify issues and improve stability

---

<div align="center">

[![Wayland Support](https://img.shields.io/badge/Wayland-Native-brightgreen?logo=wayland)](https://wayland.freedesktop.org/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-Supported-brightgreen?logo=nvidia)](https://nvidia.com)
[![Zig](https://img.shields.io/badge/Zig-0.15.0+-orange?logo=zig)](https://ziglang.org)
[![CLI & TUI](https://img.shields.io/badge/CLI_%2B_TUI-Full_Featured-blueviolet)](#features)

**The Modern NVIDIA Control Solution for Linux**

*No more missing features. No more outdated interfaces. No more compromises.*

</div>
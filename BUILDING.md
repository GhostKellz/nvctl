# Building nvctl

This document provides detailed instructions for building nvctl from source on various Linux distributions.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Build Options](#build-options)
- [Distribution-Specific Setup](#distribution-specific-setup)
- [Development Builds](#development-builds)
- [Cross-Compilation](#cross-compilation)
- [Troubleshooting](#troubleshooting)

## 🔧 Prerequisites

### Required

- **Zig 0.15.0+**: Primary build system and compiler
- **Git**: For repository cloning and submodule management
- **Linux kernel 5.4+**: For modern GPU interfaces
- **NVIDIA GPU**: For hardware testing (optional for building)

### Optional

- **NVIDIA drivers**: For full functionality testing
- **Development tools**: gdb, valgrind for debugging
- **Package managers**: For distribution packaging

## 🚀 Quick Start

### 1. Install Zig

#### Latest Zig (Recommended)
```bash
# Download and extract Zig 0.15.0
curl -LO https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz
export PATH="$PATH:$(pwd)/zig-linux-x86_64-0.15.0"

# Verify installation
zig version  # Should show 0.15.0 or newer
```

#### Package Manager Installation
```bash
# Arch Linux
sudo pacman -S zig

# Ubuntu 24.04+ (may be older version)
sudo apt install zig

# Fedora
sudo dnf install zig

# Note: Package manager versions may be outdated
# For latest features, use the official binary
```

### 2. Clone Repository

```bash
# Clone with all dependencies
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl

# Or clone and initialize submodules separately
git clone https://github.com/ghostkellz/nvctl
cd nvctl
git submodule update --init --recursive
```

### 3. Build nvctl

```bash
# Release build (recommended for daily use)
zig build -Doptimize=ReleaseSafe

# The binary will be available at:
ls zig-out/bin/nvctl

# Test the build
./zig-out/bin/nvctl --version
```

### 4. Install (Optional)

```bash
# System-wide installation
sudo cp zig-out/bin/nvctl /usr/local/bin/

# Or use the PKGBUILD for Arch Linux
makepkg -si  # From the project directory
```

## ⚙️ Build Options

### Optimization Levels

```bash
# Debug build - Best for development
zig build -Doptimize=Debug

# ReleaseSafe - Recommended for production (default)
zig build -Doptimize=ReleaseSafe

# ReleaseFast - Maximum performance, minimal safety checks
zig build -Doptimize=ReleaseFast

# ReleaseSmall - Optimize for binary size
zig build -Doptimize=ReleaseSmall
```

### Feature Flags

```bash
# Enable system tray integration (future feature)
zig build -Dsystem-tray=true

# Build for testing environment (no hardware dependencies)
zig build -Dtesting=true

# Enable all debugging features
zig build -Doptimize=Debug -Dtesting=true
```

### Build Targets

```bash
# Show available build options
zig build --help

# Run the application directly
zig build run -- gpu info

# Build and run tests
zig build test

# Clean build artifacts
zig build clean
```

## 🐧 Distribution-Specific Setup

### Arch Linux

```bash
# Install dependencies
sudo pacman -S zig git nvidia nvidia-utils base-devel

# Build and install with makepkg
makepkg -si

# Or install from AUR (when available)
yay -S nvctl-git
```

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt update
sudo apt install git build-essential

# Install latest Zig manually (recommended)
curl -LO https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz
sudo mv zig-linux-x86_64-0.15.0 /opt/zig
sudo ln -sf /opt/zig/zig /usr/local/bin/zig

# Install NVIDIA drivers (if needed)
sudo apt install nvidia-driver-535 nvidia-utils-535

# Build nvctl
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl
zig build -Doptimize=ReleaseSafe
```

### Fedora/RHEL

```bash
# Install dependencies
sudo dnf install git gcc

# Install Zig manually
curl -LO https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz
sudo mv zig-linux-x86_64-0.15.0 /opt/zig
echo 'export PATH="/opt/zig:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install NVIDIA drivers (enable RPM Fusion first)
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda

# Build nvctl
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl
zig build -Doptimize=ReleaseSafe
```

### openSUSE

```bash
# Install dependencies
sudo zypper install git gcc

# Install Zig and NVIDIA drivers
sudo zypper install zig nvidia-driver-G06

# Build nvctl
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl
zig build -Doptimize=ReleaseSafe
```

## 🔬 Development Builds

### Debug Configuration

```bash
# Full debug build with all safety checks
zig build -Doptimize=Debug

# Debug build with address sanitizer
zig build -Doptimize=Debug -Dsanitize-address

# Debug build with undefined behavior sanitizer
zig build -Doptimize=Debug -Dsanitize-undefined

# Build with all sanitizers (slowest, most thorough)
zig build -Doptimize=Debug -Dsanitize-address -Dsanitize-undefined
```

### Testing and Validation

```bash
# Run all tests
zig build test

# Run tests with verbose output
zig build test --verbose

# Run specific test file
zig test src/gpu.zig

# Run tests under valgrind (if installed)
valgrind --tool=memcheck --leak-check=full zig-out/bin/nvctl gpu info

# Performance testing with callgrind
valgrind --tool=callgrind zig-out/bin/nvctl gpu stat
```

### Code Quality Checks

```bash
# Format all source files
zig fmt src/

# Check for issues without building
zig build check

# Analyze binary size
ls -lh zig-out/bin/nvctl
strip zig-out/bin/nvctl  # Strip debug symbols for smaller size
```

## 🔄 Cross-Compilation

### Building for Different Targets

```bash
# List available targets
zig targets

# Build for specific CPU architecture
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-linux-gnu

# Build for different glibc versions
zig build -Dtarget=x86_64-linux-gnu.2.17  # CentOS 7 compatibility
```

### Static Linking

```bash
# Create fully static binary (no external dependencies)
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl

# Verify no dynamic dependencies
ldd zig-out/bin/nvctl  # Should show "not a dynamic executable"
```

## 🔧 Advanced Build Configuration

### Custom Build Scripts

```bash
# Create custom build configuration
cat > build_config.zig << 'EOF'
const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "nvctl",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = .ReleaseSafe,
    });
    
    // Add custom build options
    exe.strip = true;  // Remove debug symbols
    exe.link_libc = true;  // Link system C library
    
    b.installArtifact(exe);
}
EOF

# Use custom build script
zig build -Bbuild_config.zig
```

### Dependency Management

```bash
# Update all git submodules
git submodule update --remote

# Check dependency status
git submodule status

# Clean and rebuild dependencies
git submodule foreach --recursive git clean -xfd
git submodule update --init --recursive
zig build clean
zig build
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Zig Version Mismatch
```bash
# Error: "zig version 0.14.0 is too old"
# Solution: Install Zig 0.15.0 or newer

# Check current version
zig version

# Download latest version
curl -LO https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
```

#### 2. Missing Dependencies
```bash
# Error: "ghostnv not found" or similar
# Solution: Initialize git submodules

git submodule update --init --recursive

# Verify submodules are present
ls -la deps/  # Should show ghostnv, phantom, flash directories
```

#### 3. Build Failures
```bash
# Error: Compilation failed
# Solution: Clean and rebuild

zig build clean
rm -rf zig-cache zig-out
zig build -Doptimize=Debug  # Try debug build first
```

#### 4. Permission Issues
```bash
# Error: Permission denied accessing GPU
# Solution: Add user to video group

sudo usermod -a -G video $USER
# Then logout and login again
```

#### 5. Driver Issues
```bash
# Error: NVIDIA driver not found
# Solution: Install NVIDIA drivers

# Check if GPU is detected
lspci | grep -i nvidia

# Check if driver is loaded
lsmod | grep nvidia

# Install drivers based on your distribution (see above sections)
```

### Build Environment Debugging

```bash
# Show detailed build information
zig build --verbose

# Show compiler information
zig env

# Test minimal build
echo 'pub fn main() void {}' > test.zig
zig build-exe test.zig  # Should work if Zig is properly installed
```

### Performance Optimization

```bash
# Profile build time
time zig build -Doptimize=ReleaseSafe

# Optimize for faster builds during development
zig build -Doptimize=Debug  # Faster compilation

# Use incremental compilation (automatic in newer Zig versions)
export ZIG_INCREMENTAL=1
zig build
```

## 📦 Packaging

### Creating Distribution Packages

#### Arch Linux (PKGBUILD)
```bash
# Use included PKGBUILD
makepkg -si

# Create source package
makepkg --source
```

#### Debian/Ubuntu (.deb)
```bash
# Build portable binary first
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-gnu

# Create debian package structure
mkdir -p nvctl_0.1.0_amd64/{DEBIAN,usr/bin,usr/share/doc/nvctl}

# Package contents
cp zig-out/bin/nvctl nvctl_0.1.0_amd64/usr/bin/
cp README.md nvctl_0.1.0_amd64/usr/share/doc/nvctl/

# Create control file and build
dpkg-deb --build nvctl_0.1.0_amd64
```

#### RPM (Fedora/RHEL)
```bash
# Create RPM spec file and build
rpmbuild -ba nvctl.spec
```

## 🔍 Build Verification

### Testing the Build

```bash
# Basic functionality test
./zig-out/bin/nvctl --version
./zig-out/bin/nvctl --help

# Hardware detection test (requires NVIDIA GPU)
./zig-out/bin/nvctl gpu info

# Test without hardware (simulation mode)
NVCTL_SIMULATE=1 ./zig-out/bin/nvctl gpu info
```

### Binary Analysis

```bash
# Check binary size and dependencies
ls -lh zig-out/bin/nvctl
ldd zig-out/bin/nvctl
file zig-out/bin/nvctl

# Security analysis
checksec --file=zig-out/bin/nvctl  # If checksec is installed
```

---

## 📞 Build Support

If you encounter issues building nvctl:

1. **Check Prerequisites**: Ensure Zig 0.15.0+ is installed
2. **Verify Dependencies**: Run `git submodule status` 
3. **Clean Build**: Try `zig build clean && zig build`
4. **Create Issue**: [GitHub Issues](https://github.com/ghostkellz/nvctl/issues) with build output

### Useful Information for Bug Reports

```bash
# System information
uname -a
zig version
zig env

# Build environment
echo $PATH
which zig
ls -la deps/

# Error logs
zig build 2>&1 | tee build.log
```

---

**Maintainer**: Christopher Kelley <ckelley@ghostkellz.sh>  
**Repository**: https://github.com/ghostkellz/nvctl
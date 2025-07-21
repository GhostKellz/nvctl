# nvctl Development Guide

This document provides comprehensive information for developers working on nvctl.

## 🏗️ Architecture Overview

nvctl follows a modular architecture with clear separation of concerns, built entirely in Zig for maximum performance and safety.

### Core Principles

1. **Memory Safety**: Leveraging Zig's compile-time memory safety guarantees
2. **Performance**: Zero-cost abstractions with predictable performance
3. **Maintainability**: Clear module boundaries and comprehensive documentation
4. **Hardware Control**: Direct hardware access via ghostnv driver integration

### System Architecture

```
nvctl CLI (main.zig)
├── Core Modules
│   ├── gpu.zig (TUI Dashboard)
│   ├── display.zig (VRR Management)
│   ├── overclocking.zig (Performance Control)
│   ├── fan.zig (Thermal Management)
│   ├── drivers.zig (Package Management)
│   └── gamescope.zig (Gaming Integration)
├── Hardware Abstraction
│   └── ghostnv_integration.zig (GPU Controller)
└── System Interfaces
    ├── ghostnv (Pure Zig Driver)
    ├── phantom (TUI Framework)
    └── Linux sysfs/hwmon/drm
```

## 🛠️ Development Environment

### Prerequisites

1. **Zig 0.15.0+**: Download from [ziglang.org](https://ziglang.org/download/)
2. **NVIDIA GPU**: For hardware testing
3. **Linux Distribution**: Arch, Ubuntu, or Fedora recommended
4. **Development Tools**: git, gdb, valgrind (optional)

### Setup

```bash
# Clone repository with submodules
git clone --recursive https://github.com/ghostkellz/nvctl
cd nvctl

# Build and test
zig build -Doptimize=Debug
zig build test

# Run development version
zig build run -- gpu info
```

## 📝 Coding Standards

### Zig Style Guidelines

- **Types**: `PascalCase` (GPUController, DisplayInfo)  
- **Functions**: `camelCase` (getGpuInfo, applyOverclock)
- **Variables**: `snake_case` (gpu_count, max_temperature)
- **Constants**: `SCREAMING_SNAKE_CASE` (MAX_GPU_COUNT)

### Code Quality

- Use `zig fmt` for formatting
- Document all public APIs with `///`
- Provide specific error types
- Use `errdefer` for cleanup
- Follow RAII patterns

## 🧪 Testing

```bash
# Run all tests
zig build test

# Debug build with sanitizers
zig build -Doptimize=Debug -Dsanitize=address

# Memory leak detection
valgrind ./zig-out/bin/nvctl gpu info
```

## 🤝 Contributing

1. Fork and create feature branch
2. Follow Zig coding standards
3. Add tests for new functionality
4. Update documentation
5. Submit pull request

See full documentation in repository for detailed guidelines.

---

**Maintainer**: Christopher Kelley <ckelley@ghostkellz.sh>
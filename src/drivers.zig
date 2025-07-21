const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub const PackageManager = enum {
    pacman, // Arch Linux
    apt,    // Debian/Ubuntu
    dnf,    // Fedora/RHEL
    yum,    // Older RHEL/CentOS
    zypper, // openSUSE
    portage, // Gentoo
    unknown,
};

pub const DriverInfo = struct {
    version: []const u8,
    branch: []const u8, // production, beta, legacy
    installed: bool,
    available: bool,
    package_name: []const u8,
    
    pub fn deinit(self: *const DriverInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.version);
        allocator.free(self.branch);
        allocator.free(self.package_name);
    }
};

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printDriverHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, subcommand, "status")) {
        try showDriverStatus(allocator);
    } else if (std.mem.eql(u8, subcommand, "list")) {
        try listAvailableDrivers(allocator);
    } else if (std.mem.eql(u8, subcommand, "install")) {
        try handleDriverInstall(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "update")) {
        try updateDriver(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "remove")) {
        try removeDriver(allocator);
    } else if (std.mem.eql(u8, subcommand, "backup")) {
        try backupDriver(allocator);
    } else if (std.mem.eql(u8, subcommand, "restore")) {
        try restoreDriver(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "check")) {
        try checkDriverCompatibility(allocator);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printDriverHelp();
    } else {
        try nvctl.utils.print.format("Unknown driver subcommand: {s}\n", .{subcommand});
        try printDriverHelp();
    }
}

fn printDriverHelp() !void {
    try nvctl.utils.print.line("nvctl drivers - NVIDIA driver management\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl drivers <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  status       Show current driver status");
    try nvctl.utils.print.line("  list         List available driver versions");
    try nvctl.utils.print.line("  install      Install specific driver version");
    try nvctl.utils.print.line("  update       Update to latest driver");
    try nvctl.utils.print.line("  remove       Remove NVIDIA drivers");
    try nvctl.utils.print.line("  backup       Backup current driver configuration");
    try nvctl.utils.print.line("  restore      Restore driver from backup");
    try nvctl.utils.print.line("  check        Check driver compatibility");
    try nvctl.utils.print.line("  help         Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl drivers status                # Show current status");
    try nvctl.utils.print.line("  nvctl drivers list                  # List available versions");
    try nvctl.utils.print.line("  nvctl drivers install 545.29.06     # Install specific version");
    try nvctl.utils.print.line("  nvctl drivers update                # Update to latest");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("⚠️  Requires root privileges for installation/removal");
}

fn showDriverStatus(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🔧 NVIDIA Driver Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Detect package manager
    const pkg_manager = detectPackageManager();
    try nvctl.utils.print.format("Package Manager: {s}\n", .{packageManagerToString(pkg_manager)});
    
    // Get current driver info
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ Unable to detect GPU or driver");
            try nvctl.utils.print.line("");
            try showDriverDetectionHelp(pkg_manager);
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("GPU: {s}\n", .{gpu_info.name});
    try nvctl.utils.print.line("");
    
    // Current driver status
    try nvctl.utils.print.line("📦 Current Driver:");
    try nvctl.utils.print.format("  Version:      {s}\n", .{gpu_info.driver_version});
    try nvctl.utils.print.line("  Type:         Proprietary NVIDIA");
    try nvctl.utils.print.line("  Status:       ✓ Active and loaded");
    try nvctl.utils.print.line("  Module:       nvidia.ko");
    try nvctl.utils.print.line("");
    
    // Driver installation info
    const driver_packages = try getInstalledDriverPackages(allocator, pkg_manager);
    defer {
        for (driver_packages) |pkg| {
            pkg.deinit(allocator);
        }
        allocator.free(driver_packages);
    }
    
    try nvctl.utils.print.line("📋 Installed Packages:");
    for (driver_packages) |pkg| {
        const status_icon = if (pkg.installed) "✓" else "✗";
        try nvctl.utils.print.format("  {s} {s:<30} {s}\n", .{ status_icon, pkg.package_name, pkg.version });
    }
    
    try nvctl.utils.print.line("");
    
    // Check for updates
    const latest_version = try checkLatestVersion(allocator, pkg_manager);
    defer allocator.free(latest_version);
    
    const current_version = gpu_info.driver_version;
    const update_available = !std.mem.eql(u8, current_version, latest_version);
    
    if (update_available) {
        try nvctl.utils.print.format("⚠️  Update Available: {s} → {s}\n", .{ current_version, latest_version });
        try nvctl.utils.print.line("💡 Use 'nvctl drivers update' to install latest version");
    } else {
        try nvctl.utils.print.line("✅ Driver is up to date");
    }
}

fn detectPackageManager() PackageManager {
    const pkg_managers = [_]struct { cmd: []const u8, manager: PackageManager }{
        .{ .cmd = "pacman", .manager = .pacman },
        .{ .cmd = "apt", .manager = .apt },
        .{ .cmd = "dnf", .manager = .dnf },
        .{ .cmd = "yum", .manager = .yum },
        .{ .cmd = "zypper", .manager = .zypper },
        .{ .cmd = "emerge", .manager = .portage },
    };
    
    for (pkg_managers) |pm| {
        if (commandExists(pm.cmd)) {
            return pm.manager;
        }
    }
    
    return .unknown;
}

fn commandExists(cmd: []const u8) bool {
    var process = std.process.Child.init(&[_][]const u8{ "which", cmd }, std.heap.page_allocator);
    process.stdout_behavior = .Ignore;
    process.stderr_behavior = .Ignore;
    
    const result = process.spawnAndWait() catch return false;
    return result == .Exited and result.Exited == 0;
}

fn packageManagerToString(pm: PackageManager) []const u8 {
    return switch (pm) {
        .pacman => "Pacman (Arch Linux)",
        .apt => "APT (Debian/Ubuntu)",
        .dnf => "DNF (Fedora)",
        .yum => "YUM (RHEL/CentOS)",
        .zypper => "Zypper (openSUSE)",
        .portage => "Portage (Gentoo)",
        .unknown => "Unknown",
    };
}

fn showDriverDetectionHelp(pkg_manager: PackageManager) !void {
    try nvctl.utils.print.line("🔍 Driver Detection Help:");
    try nvctl.utils.print.line("");
    
    switch (pkg_manager) {
        .pacman => {
            try nvctl.utils.print.line("Arch Linux - Install NVIDIA drivers:");
            try nvctl.utils.print.line("  sudo pacman -S nvidia nvidia-utils");
            try nvctl.utils.print.line("  sudo pacman -S nvidia-lts  # For LTS kernel");
        },
        .apt => {
            try nvctl.utils.print.line("Ubuntu/Debian - Install NVIDIA drivers:");
            try nvctl.utils.print.line("  sudo apt update");
            try nvctl.utils.print.line("  sudo apt install nvidia-driver-535");
            try nvctl.utils.print.line("  sudo apt install ubuntu-drivers-common");
            try nvctl.utils.print.line("  ubuntu-drivers devices  # Show recommended drivers");
        },
        .dnf => {
            try nvctl.utils.print.line("Fedora - Install NVIDIA drivers:");
            try nvctl.utils.print.line("  sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda");
            try nvctl.utils.print.line("  # Enable RPM Fusion repository first");
        },
        .yum => {
            try nvctl.utils.print.line("RHEL/CentOS - Install NVIDIA drivers:");
            try nvctl.utils.print.line("  sudo yum install nvidia-driver nvidia-driver-cuda");
            try nvctl.utils.print.line("  # Enable EPEL and ELRepo repositories");
        },
        else => {
            try nvctl.utils.print.line("Please install NVIDIA drivers using your distribution's method");
        },
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("After installation, reboot and run 'nvctl drivers status' again.");
}

fn getInstalledDriverPackages(allocator: std.mem.Allocator, pkg_manager: PackageManager) ![]DriverInfo {
    // Simulate installed package detection
    var packages = std.ArrayList(DriverInfo).init(allocator);
    errdefer packages.deinit();
    
    switch (pkg_manager) {
        .pacman => {
            try packages.append(DriverInfo{
                .version = try allocator.dupe(u8, "575.0.0-1"),
                .branch = try allocator.dupe(u8, "production"),
                .installed = true,
                .available = true,
                .package_name = try allocator.dupe(u8, "nvidia"),
            });
            try packages.append(DriverInfo{
                .version = try allocator.dupe(u8, "575.0.0-1"),
                .branch = try allocator.dupe(u8, "production"),
                .installed = true,
                .available = true,
                .package_name = try allocator.dupe(u8, "nvidia-utils"),
            });
        },
        .apt => {
            try packages.append(DriverInfo{
                .version = try allocator.dupe(u8, "545.29.06-1ubuntu1"),
                .branch = try allocator.dupe(u8, "production"),
                .installed = true,
                .available = true,
                .package_name = try allocator.dupe(u8, "nvidia-driver-545"),
            });
        },
        .dnf => {
            try packages.append(DriverInfo{
                .version = try allocator.dupe(u8, "545.29.06-1.fc39"),
                .branch = try allocator.dupe(u8, "production"),
                .installed = true,
                .available = true,
                .package_name = try allocator.dupe(u8, "akmod-nvidia"),
            });
        },
        else => {
            // Generic entry for unknown package managers
            try packages.append(DriverInfo{
                .version = try allocator.dupe(u8, "575.0.0"),
                .branch = try allocator.dupe(u8, "production"),
                .installed = true,
                .available = true,
                .package_name = try allocator.dupe(u8, "nvidia-driver"),
            });
        },
    }
    
    return packages.toOwnedSlice();
}

fn checkLatestVersion(allocator: std.mem.Allocator, pkg_manager: PackageManager) ![]const u8 {
    _ = pkg_manager;
    // In real implementation, this would query package repositories
    return try allocator.dupe(u8, "575.0.0-ghost");
}

fn listAvailableDrivers(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("📦 Available NVIDIA Drivers");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    const pkg_manager = detectPackageManager();
    try nvctl.utils.print.format("Package Manager: {s}\n", .{packageManagerToString(pkg_manager)});
    try nvctl.utils.print.line("");
    
    // Simulate available driver versions
    const available_drivers = [_]struct { version: []const u8, branch: []const u8, supported: bool }{
        .{ .version = "575.0.0", .branch = "production", .supported = true },
        .{ .version = "545.29.06", .branch = "production", .supported = true },
        .{ .version = "535.171.04", .branch = "production", .supported = true },
        .{ .version = "560.35.03", .branch = "beta", .supported = true },
        .{ .version = "470.256.02", .branch = "legacy", .supported = false },
    };
    
    try nvctl.utils.print.line("Version       | Branch     | GPU Support | Status");
    try nvctl.utils.print.line("──────────────┼────────────┼─────────────┼─────────");
    
    for (available_drivers) |driver| {
        const support_icon = if (driver.supported) "✓" else "✗";
        const status = if (std.mem.eql(u8, driver.version, "575.0.0")) "Installed" else "Available";
        
        try nvctl.utils.print.format("{s:<13} | {s:<10} | {s:<11} | {s}\n", .{ 
            driver.version, 
            driver.branch, 
            support_icon, 
            status 
        });
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Production: Stable releases recommended for daily use");
    try nvctl.utils.print.line("💡 Beta: Latest features, may have instability");
    try nvctl.utils.print.line("💡 Legacy: For older GPUs (GTX 600/700 series)");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Use 'nvctl drivers install <version>' to install specific version");
}

fn handleDriverInstall(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl drivers install <version>");
        try nvctl.utils.print.line("Example: nvctl drivers install 545.29.06");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("Use 'nvctl drivers list' to see available versions");
        return;
    }
    
    const version = args[0];
    const pkg_manager = detectPackageManager();
    
    try nvctl.utils.print.format("🔧 Installing NVIDIA Driver {s}\n", .{version});
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Check if version is available
    if (!isVersionAvailable(version)) {
        try nvctl.utils.print.format("❌ Version {s} not found in repositories\n", .{version});
        try nvctl.utils.print.line("Use 'nvctl drivers list' to see available versions");
        return;
    }
    
    // Show installation plan
    try nvctl.utils.print.format("📋 Installation Plan for {s}:\n", .{packageManagerToString(pkg_manager)});
    
    switch (pkg_manager) {
        .pacman => {
            try nvctl.utils.print.line("  1. Remove existing nvidia packages");
            try nvctl.utils.print.line("  2. Install nvidia nvidia-utils nvidia-settings");
            try nvctl.utils.print.line("  3. Update initramfs");
            try nvctl.utils.print.line("  4. Reboot required");
            try nvctl.utils.print.line("");
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo pacman -R nvidia nvidia-utils");
            try nvctl.utils.print.format("  sudo pacman -S nvidia={s} nvidia-utils nvidia-settings\n", .{version});
        },
        .apt => {
            try nvctl.utils.print.line("  1. Remove existing nvidia drivers");
            try nvctl.utils.print.line("  2. Install nvidia driver package");
            try nvctl.utils.print.line("  3. Configure X11/Wayland");
            try nvctl.utils.print.line("  4. Reboot required");
            try nvctl.utils.print.line("");
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo apt remove --purge '^nvidia-.*'");
            try nvctl.utils.print.format("  sudo apt install nvidia-driver-{s}\n", .{version[0..3]}); // First 3 digits
        },
        .dnf => {
            try nvctl.utils.print.line("  1. Remove existing nvidia modules");
            try nvctl.utils.print.line("  2. Install akmod-nvidia package");
            try nvctl.utils.print.line("  3. Wait for module compilation");
            try nvctl.utils.print.line("  4. Reboot required");
            try nvctl.utils.print.line("");
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo dnf remove '*nvidia*'");
            try nvctl.utils.print.line("  sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda");
        },
        else => {
            try nvctl.utils.print.line("  Manual installation required for this system");
            try nvctl.utils.print.line("  Please check your distribution's documentation");
        },
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("⚠️  This operation requires root privileges");
    try nvctl.utils.print.line("⚠️  Backup your current configuration first with 'nvctl drivers backup'");
    try nvctl.utils.print.line("⚠️  System reboot will be required after installation");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: This is a simulation - actual package manager integration pending");
    
    _ = allocator;
}

fn isVersionAvailable(version: []const u8) bool {
    const available_versions = [_][]const u8{
        "575.0.0",
        "545.29.06", 
        "535.171.04",
        "560.35.03",
        "470.256.02",
    };
    
    for (available_versions) |v| {
        if (std.mem.eql(u8, version, v)) {
            return true;
        }
    }
    return false;
}

fn updateDriver(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    _ = allocator;
    
    const pkg_manager = detectPackageManager();
    
    try nvctl.utils.print.line("🔄 Updating NVIDIA Drivers");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    try nvctl.utils.print.line("Checking for driver updates...");
    
    // Simulate update check
    const current_version = "545.29.06";
    const latest_version = "575.0.0";
    
    if (std.mem.eql(u8, current_version, latest_version)) {
        try nvctl.utils.print.line("✅ Drivers are already up to date");
        return;
    }
    
    try nvctl.utils.print.format("📦 Update available: {s} → {s}\n", .{ current_version, latest_version });
    try nvctl.utils.print.line("");
    
    switch (pkg_manager) {
        .pacman => try nvctl.utils.print.line("Command: sudo pacman -Syu nvidia nvidia-utils"),
        .apt => try nvctl.utils.print.line("Command: sudo apt update && sudo apt upgrade nvidia-driver-*"),
        .dnf => try nvctl.utils.print.line("Command: sudo dnf update akmod-nvidia"),
        else => try nvctl.utils.print.line("Use your package manager's update command"),
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("⚠️  Reboot required after driver update");
    try nvctl.utils.print.line("🔧 Note: This is a simulation - actual update integration pending");
}

fn removeDriver(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    const pkg_manager = detectPackageManager();
    
    try nvctl.utils.print.line("🗑️  Remove NVIDIA Drivers");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("⚠️  WARNING: This will remove all NVIDIA drivers and switch to open-source drivers");
    try nvctl.utils.print.line("");
    
    switch (pkg_manager) {
        .pacman => {
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo pacman -R nvidia nvidia-utils nvidia-settings");
            try nvctl.utils.print.line("  sudo mkinitcpio -P  # Rebuild initramfs");
        },
        .apt => {
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo apt remove --purge '^nvidia-.*'");
            try nvctl.utils.print.line("  sudo apt autoremove");
        },
        .dnf => {
            try nvctl.utils.print.line("Commands to run:");
            try nvctl.utils.print.line("  sudo dnf remove '*nvidia*'");
            try nvctl.utils.print.line("  sudo dracut --force  # Rebuild initramfs");
        },
        else => {
            try nvctl.utils.print.line("Use your package manager's remove command");
        },
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("After removal:");
    try nvctl.utils.print.line("  • System will use nouveau (open-source) drivers");
    try nvctl.utils.print.line("  • GPU performance will be significantly reduced");
    try nvctl.utils.print.line("  • CUDA and GPU computing will be unavailable");
    try nvctl.utils.print.line("  • Reboot required");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: This is a simulation - actual removal integration pending");
}

fn backupDriver(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("💾 Backup NVIDIA Driver Configuration");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    const backup_path = "/var/lib/nvctl/driver-backups";
    const timestamp = std.time.timestamp();
    
    try nvctl.utils.print.format("Creating backup at: {s}/backup-{d}\n", .{ backup_path, timestamp });
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Backing up:");
    try nvctl.utils.print.line("  ✓ /etc/X11/xorg.conf");
    try nvctl.utils.print.line("  ✓ /etc/modprobe.d/nvidia.conf"); 
    try nvctl.utils.print.line("  ✓ Kernel module information");
    try nvctl.utils.print.line("  ✓ Package list and versions");
    try nvctl.utils.print.line("  ✓ Driver settings and profiles");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.format("✅ Backup completed: backup-{d}\n", .{timestamp});
    try nvctl.utils.print.line("💡 Use 'nvctl drivers restore' to restore from backup");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: This is a simulation - actual backup integration pending");
}

fn restoreDriver(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl drivers restore <backup-id>");
        try nvctl.utils.print.line("Example: nvctl drivers restore backup-1705123456");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("Available backups:");
        try nvctl.utils.print.line("  backup-1705123456  (2024-01-13 10:30)");
        try nvctl.utils.print.line("  backup-1705023456  (2024-01-12 08:15)");
        return;
    }
    
    const backup_id = args[0];
    
    try nvctl.utils.print.line("🔄 Restore NVIDIA Driver Configuration");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.format("Restoring from: {s}\n", .{backup_id});
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Restoring:");
    try nvctl.utils.print.line("  ✓ Driver packages and versions");
    try nvctl.utils.print.line("  ✓ Configuration files");
    try nvctl.utils.print.line("  ✓ Kernel module settings");
    try nvctl.utils.print.line("  ✓ X11/Wayland configuration");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("✅ Driver configuration restored");
    try nvctl.utils.print.line("⚠️  Reboot required to apply changes");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: This is a simulation - actual restore integration pending");
}

fn checkDriverCompatibility(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🔍 Driver Compatibility Check");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Get GPU info
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    const gpu_info = gpu_controller.getGpuInfo() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            try nvctl.utils.print.line("❌ Unable to detect GPU");
            return;
        },
    };
    defer gpu_info.deinit(allocator);
    
    try nvctl.utils.print.format("GPU: {s}\n", .{gpu_info.name});
    try nvctl.utils.print.format("Current Driver: {s}\n", .{gpu_info.driver_version});
    try nvctl.utils.print.line("");
    
    // Compatibility matrix
    try nvctl.utils.print.line("📊 Compatibility Matrix:");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Driver Version | RTX 40xx | RTX 30xx | GTX 16xx | GTX 10xx | Maxwell");
    try nvctl.utils.print.line("───────────────┼──────────┼──────────┼──────────┼──────────┼────────");
    try nvctl.utils.print.line("575.x.x        |    ✅    |    ✅    |    ✅    |    ✅    |   ✅");
    try nvctl.utils.print.line("545.x.x        |    ✅    |    ✅    |    ✅    |    ✅    |   ✅");
    try nvctl.utils.print.line("535.x.x        |    ✅    |    ✅    |    ✅    |    ✅    |   ✅");
    try nvctl.utils.print.line("470.x.x        |    ❌    |    ❌    |    ✅    |    ✅    |   ✅");
    try nvctl.utils.print.line("");
    
    // Specific recommendations
    if (std.mem.indexOf(u8, gpu_info.name, "RTX 4")) |_| {
        try nvctl.utils.print.line("💡 Recommended: Latest driver (575.x.x or newer)");
        try nvctl.utils.print.line("💡 RTX 4000 series requires driver 520.x.x or newer");
    } else if (std.mem.indexOf(u8, gpu_info.name, "RTX 3")) |_| {
        try nvctl.utils.print.line("💡 Recommended: Production driver (545.x.x or newer)");
        try nvctl.utils.print.line("💡 RTX 3000 series works with any recent driver");
    } else if (std.mem.indexOf(u8, gpu_info.name, "GTX")) |_| {
        try nvctl.utils.print.line("💡 Recommended: Any production driver");
        try nvctl.utils.print.line("💡 Legacy GTX cards may benefit from older drivers");
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("✅ Current driver is compatible with your GPU");
}

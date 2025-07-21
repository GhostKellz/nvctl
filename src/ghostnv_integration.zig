const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

/// GhostNV Integration Layer for nvctl
/// Provides a bridge between nvctl commands and the ghostnv driver

pub const GPUController = struct {
    allocator: std.mem.Allocator,
    driver_initialized: bool = false,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Self) void {
        _ = self;
        // Cleanup ghostnv resources
    }
    
    pub fn initializeDriver(self: *Self) !void {
        // Try to initialize ghostnv driver connection
        // For now, we'll detect basic GPU presence
        self.driver_initialized = self.detectGhostNvDriver();
    }
    
    fn detectGhostNvDriver(self: *Self) bool {
        _ = self;
        // Check for ghostnv driver presence
        const kernel_modules = [_][]const u8{
            "/sys/module/nvidia",
            "/sys/module/nvidia_drm", 
            "/proc/driver/nvidia",
        };
        
        for (kernel_modules) |module_path| {
            var dir = std.fs.cwd().openDir(module_path, .{}) catch continue;
            dir.close();
            return true; // Found NVIDIA driver
        }
        return false;
    }
    
    pub fn getGpuInfo(self: *Self) !GpuInfo {
        if (!self.driver_initialized) {
            try self.initializeDriver();
        }
        
        // Use ghostnv APIs when available, fall back to sysfs
        return try self.getGpuInfoSysfs();
    }
    
    fn getGpuInfoSysfs(self: *Self) !GpuInfo {
        const pci_path = "/sys/class/drm";
        
        var dir = std.fs.cwd().openDir(pci_path, .{ .iterate = true }) catch {
            return error.NoGpuFound;
        };
        defer dir.close();
        
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.startsWith(u8, entry.name, "card")) {
                // Found a GPU card, try to get vendor info
                const vendor_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}/device/vendor", .{ pci_path, entry.name });
                defer self.allocator.free(vendor_path);
                
                const vendor_file = std.fs.cwd().openFile(vendor_path, .{}) catch continue;
                defer vendor_file.close();
                
                var vendor_buf: [32]u8 = undefined;
                const vendor_bytes = vendor_file.readAll(&vendor_buf) catch continue;
                const vendor_str = std.mem.trim(u8, vendor_buf[0..vendor_bytes], " \n\r\t");
                
                // Check if it's NVIDIA (0x10de)
                if (std.mem.eql(u8, vendor_str, "0x10de")) {
                    return GpuInfo{
                        .name = try self.getGpuName(entry.name),
                        .driver_version = try self.getDriverVersion(),
                        .architecture = try self.allocator.dupe(u8, "Unknown"),
                        .pci_id = try self.allocator.dupe(u8, vendor_str),
                        .vram_total = try self.getVramSize(entry.name),
                        .compute_capability = try self.allocator.dupe(u8, "Unknown"),
                        .temperature = try self.getTemperature(),
                        .power_usage = try self.getPowerUsage(),
                        .utilization = try self.getUtilization(),
                    };
                }
            }
        }
        
        return error.NoNvidiaGpu;
    }
    
    fn getGpuName(self: *Self, card_name: []const u8) ![]const u8 {
        // Try to get GPU name from multiple sources
        const sources = [_][]const u8{
            "device/subsystem_device",
            "device/device", 
        };
        
        for (sources) |source| {
            const path = try std.fmt.allocPrint(self.allocator, "/sys/class/drm/{s}/{s}", .{ card_name, source });
            defer self.allocator.free(path);
            
            const file = std.fs.cwd().openFile(path, .{}) catch continue;
            defer file.close();
            
            var buf: [64]u8 = undefined;
            const bytes_read = file.readAll(&buf) catch continue;
            const device_id = std.mem.trim(u8, buf[0..bytes_read], " \n\r\t");
            
            // Map common device IDs to GPU names
            const gpu_name = mapDeviceIdToName(device_id);
            if (gpu_name != null) {
                return try self.allocator.dupe(u8, gpu_name.?);
            }
        }
        
        return try self.allocator.dupe(u8, "NVIDIA GPU");
    }
    
    fn mapDeviceIdToName(device_id: []const u8) ?[]const u8 {
        // Map common NVIDIA device IDs to GPU names
        const device_map = std.StaticStringMap([]const u8).initComptime(.{
            .{ "0x2684", "RTX 4090" },
            .{ "0x2782", "RTX 4070 Ti" },
            .{ "0x2786", "RTX 4070" },
            .{ "0x2504", "RTX 3090" },
            .{ "0x2206", "RTX 3080" },
            .{ "0x2484", "RTX 3070" },
            // Add more mappings as needed
        });
        
        return device_map.get(device_id);
    }
    
    fn getDriverVersion(self: *Self) ![]const u8 {
        const proc_version_paths = [_][]const u8{
            "/proc/driver/nvidia/version",
            "/sys/module/nvidia/version",
        };
        
        for (proc_version_paths) |path| {
            const file = std.fs.cwd().openFile(path, .{}) catch continue;
            defer file.close();
            
            var buf: [256]u8 = undefined;
            const bytes_read = file.readAll(&buf) catch continue;
            const content = std.mem.trim(u8, buf[0..bytes_read], " \n\r\t");
            
            if (std.mem.indexOf(u8, content, "NVIDIA")) |_| {
                if (std.mem.indexOf(u8, content, "\n")) |newline| {
                    return try self.allocator.dupe(u8, content[0..newline]);
                } else {
                    return try self.allocator.dupe(u8, content);
                }
            }
        }
        
        return try self.allocator.dupe(u8, "575.0.0-ghost (ghostnv)");
    }
    
    fn getVramSize(self: *Self, card_name: []const u8) !u64 {
        _ = card_name;
        // TODO: Implement VRAM detection via ghostnv or sysfs
        _ = self;
        return 0;
    }
    
    fn getTemperature(self: *Self) !u32 {
        // Try to read temperature from hwmon
        const hwmon_path = "/sys/class/hwmon";
        
        var dir = std.fs.cwd().openDir(hwmon_path, .{ .iterate = true }) catch return 0;
        defer dir.close();
        
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const temp_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}/temp1_input", .{ hwmon_path, entry.name });
            defer self.allocator.free(temp_path);
            
            const file = std.fs.cwd().openFile(temp_path, .{}) catch continue;
            defer file.close();
            
            var buf: [16]u8 = undefined;
            const bytes_read = file.readAll(&buf) catch continue;
            const temp_str = std.mem.trim(u8, buf[0..bytes_read], " \n\r\t");
            
            const temp_millicelsius = std.fmt.parseInt(u32, temp_str, 10) catch continue;
            return temp_millicelsius / 1000; // Convert from millicelsius
        }
        
        return 0;
    }
    
    fn getPowerUsage(self: *Self) !u32 {
        _ = self;
        // TODO: Implement power usage detection
        return 0;
    }
    
    fn getUtilization(self: *Self) !u32 {
        _ = self;
        // TODO: Implement GPU utilization detection
        return 0;
    }
};

pub const DisplayController = struct {
    allocator: std.mem.Allocator,
    gpu_controller: *GPUController,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, gpu_controller: *GPUController) Self {
        return Self{
            .allocator = allocator,
            .gpu_controller = gpu_controller,
        };
    }
    
    pub fn deinit(self: *Self) void {
        _ = self;
    }
    
    pub fn listDisplays(self: *Self) ![]DisplayInfo {
        // TODO: Use ghostnv display enumeration
        // For now, return basic drm display detection
        return try self.getDisplaysFromDrm();
    }
    
    fn getDisplaysFromDrm(self: *Self) ![]DisplayInfo {
        var displays = std.ArrayList(DisplayInfo).init(self.allocator);
        errdefer displays.deinit();
        
        const drm_path = "/sys/class/drm";
        var dir = std.fs.cwd().openDir(drm_path, .{ .iterate = true }) catch return displays.toOwnedSlice();
        defer dir.close();
        
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.indexOf(u8, entry.name, "-")) |_| {
                // This is likely a connector (e.g., "card0-DP-1", "card0-HDMI-A-1")
                const display_info = DisplayInfo{
                    .id = @intCast(displays.items.len),
                    .name = try self.allocator.dupe(u8, entry.name),
                    .manufacturer = try self.allocator.dupe(u8, "Unknown"),
                    .model = try self.allocator.dupe(u8, "Unknown"),
                    .connection_type = try self.extractConnectionType(entry.name),
                    .resolution_width = 1920,
                    .resolution_height = 1080,
                    .refresh_rate = 60,
                    .hdr_enabled = false,
                    .hdr_capable = false,
                    .vibrance = 0.0,
                };
                
                try displays.append(display_info);
            }
        }
        
        return displays.toOwnedSlice();
    }
    
    fn extractConnectionType(self: *Self, connector_name: []const u8) ![]const u8 {
        if (std.mem.indexOf(u8, connector_name, "DP")) |_| {
            return try self.allocator.dupe(u8, "DisplayPort");
        } else if (std.mem.indexOf(u8, connector_name, "HDMI")) |_| {
            return try self.allocator.dupe(u8, "HDMI");
        } else if (std.mem.indexOf(u8, connector_name, "DVI")) |_| {
            return try self.allocator.dupe(u8, "DVI");
        } else {
            return try self.allocator.dupe(u8, "Unknown");
        }
    }
    
    pub fn setDigitalVibrance(self: *Self, display_id: u32, level: f32) !void {
        _ = self;
        _ = display_id;
        _ = level;
        // TODO: Use ghostnv digital vibrance APIs
        return error.NotImplemented;
    }
    
    pub fn enableHDR(self: *Self, display_id: u32) !void {
        _ = self;
        _ = display_id;
        // TODO: Use ghostnv HDR control APIs
        return error.NotImplemented;
    }
};

pub const GpuInfo = struct {
    name: []const u8,
    driver_version: []const u8,
    architecture: []const u8,
    pci_id: []const u8,
    vram_total: u64,
    compute_capability: []const u8,
    temperature: u32,
    power_usage: u32,
    utilization: u32,
    
    pub fn deinit(self: *const GpuInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.driver_version);
        allocator.free(self.architecture);
        allocator.free(self.pci_id);
        allocator.free(self.compute_capability);
    }
};

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
    
    pub fn deinit(self: *const DisplayInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.manufacturer);
        allocator.free(self.model);
        allocator.free(self.connection_type);
    }
};
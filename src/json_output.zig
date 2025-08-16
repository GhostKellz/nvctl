//! JSON Output Support for NVCTL
//! 
//! Provides structured JSON output for all GPU information and operations
//! for automation and scripting support.

const std = @import("std");
const integration = @import("ghostnv_integration.zig");

/// JSON formatter for GPU information
pub const JSONFormatter = struct {
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    /// Format GPU info as JSON
    pub fn formatGpuInfo(self: *Self, gpu_info: integration.GpuInfo) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        
        try json.appendSlice("{\n");
        try json.appendSlice("  \"gpu\": {\n");
        try json.writer().print("    \"name\": \"{s}\",\n", .{gpu_info.name});
        try json.writer().print("    \"driver_version\": \"{s}\",\n", .{gpu_info.driver_version});
        try json.writer().print("    \"architecture\": \"{s}\",\n", .{gpu_info.architecture});
        try json.writer().print("    \"pci_id\": \"{s}\",\n", .{gpu_info.pci_id});
        try json.writer().print("    \"vram_total_mb\": {},\n", .{gpu_info.vram_total / (1024 * 1024)});
        try json.writer().print("    \"compute_capability\": \"{s}\",\n", .{gpu_info.compute_capability});
        try json.writer().print("    \"temperature_celsius\": {},\n", .{gpu_info.temperature});
        try json.writer().print("    \"power_usage_watts\": {},\n", .{gpu_info.power_usage});
        try json.writer().print("    \"utilization_percent\": {},\n", .{gpu_info.utilization});
        try json.writer().print("    \"timestamp\": {}\n", .{std.time.milliTimestamp()});
        try json.appendSlice("  }\n");
        try json.appendSlice("}\n");
        
        return try self.allocator.dupe(u8, json.items);
    }
    
    /// Format metrics snapshot as JSON
    pub fn formatMetrics(self: *Self, metrics: integration.MonitoringManager.MetricsSnapshot) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        
        try json.appendSlice("{\n");
        try json.appendSlice("  \"metrics\": {\n");
        try json.writer().print("    \"timestamp\": {},\n", .{metrics.timestamp});
        try json.writer().print("    \"gpu_id\": {},\n", .{metrics.gpu_id});
        try json.writer().print("    \"temperature_celsius\": {d:.1f},\n", .{metrics.temperature});
        try json.writer().print("    \"power_usage_watts\": {},\n", .{metrics.power_usage});
        try json.writer().print("    \"utilization_percent\": {},\n", .{metrics.utilization});
        try json.writer().print("    \"memory_used_mb\": {},\n", .{metrics.memory_used_mb});
        try json.writer().print("    \"memory_total_mb\": {},\n", .{metrics.memory_total_mb});
        try json.writer().print("    \"core_clock_mhz\": {},\n", .{metrics.core_clock_mhz});
        try json.writer().print("    \"memory_clock_mhz\": {},\n", .{metrics.memory_clock_mhz});
        try json.writer().print("    \"fan_speed_percent\": {},\n", .{metrics.fan_speed_percent});
        try json.writer().print("    \"voltage_mv\": {}\n", .{metrics.voltage_mv});
        try json.appendSlice("  }\n");
        try json.appendSlice("}\n");
        
        return try self.allocator.dupe(u8, json.items);
    }
    
    /// Format display information as JSON
    pub fn formatDisplays(self: *Self, displays: []const integration.DisplayController.DisplayInfo) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        
        try json.appendSlice("{\n");
        try json.appendSlice("  \"displays\": [\n");
        
        for (displays, 0..) |display, i| {
            try json.appendSlice("    {\n");
            try json.writer().print("      \"id\": {},\n", .{display.id});
            try json.writer().print("      \"name\": \"{s}\",\n", .{display.name});
            try json.writer().print("      \"connection_type\": \"{s}\",\n", .{@tagName(display.connection)});
            try json.writer().print("      \"resolution\": {{\n");
            try json.writer().print("        \"width\": {},\n", .{display.resolution.width});
            try json.writer().print("        \"height\": {}\n", .{display.resolution.height});
            try json.appendSlice("      },\n");
            try json.writer().print("      \"refresh_rate\": {},\n", .{display.refresh_rate});
            try json.writer().print("      \"hdr_capable\": {},\n", .{display.hdr_capable});
            try json.writer().print("      \"vrr_capable\": {}\n", .{display.vrr_capable});
            try json.appendSlice("    }");
            
            if (i < displays.len - 1) {
                try json.appendSlice(",");
            }
            try json.appendSlice("\n");
        }
        
        try json.appendSlice("  ]\n");
        try json.appendSlice("}\n");
        
        return try self.allocator.dupe(u8, json.items);
    }
    
    /// Format error as JSON
    pub fn formatError(self: *Self, error_msg: []const u8) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        
        try json.appendSlice("{\n");
        try json.appendSlice("  \"error\": {\n");
        try json.writer().print("    \"message\": \"{s}\",\n", .{error_msg});
        try json.writer().print("    \"timestamp\": {}\n", .{std.time.milliTimestamp()});
        try json.appendSlice("  }\n");
        try json.appendSlice("}\n");
        
        return try self.allocator.dupe(u8, json.items);
    }
    
    /// Format success operation as JSON
    pub fn formatSuccess(self: *Self, operation: []const u8, details: []const u8) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();
        
        try json.appendSlice("{\n");
        try json.appendSlice("  \"success\": {\n");
        try json.writer().print("    \"operation\": \"{s}\",\n", .{operation});
        try json.writer().print("    \"details\": \"{s}\",\n", .{details});
        try json.writer().print("    \"timestamp\": {}\n", .{std.time.milliTimestamp()});
        try json.appendSlice("  }\n");
        try json.appendSlice("}\n");
        
        return try self.allocator.dupe(u8, json.items);
    }
};
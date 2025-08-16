//! TUI Enhancement Utilities for NVCTL
//! 
//! Provides keyboard shortcuts, real-time graphs, and interactive controls
//! for the enhanced Phantom TUI interface.

const std = @import("std");
const phantom = @import("phantom");
const integration = @import("ghostnv_integration.zig");

/// Keyboard shortcut handler for the TUI
pub const KeyboardHandler = struct {
    allocator: std.mem.Allocator,
    tui: *anyopaque, // Reference to EnhancedTUI
    
    const Self = @This();
    
    pub const KeyBinding = struct {
        key: phantom.Key,
        modifier: ?phantom.Modifier = null,
        description: []const u8,
        callback: *const fn(tui: *anyopaque) void,
    };
    
    pub fn init(allocator: std.mem.Allocator, tui: *anyopaque) Self {
        return Self{
            .allocator = allocator,
            .tui = tui,
        };
    }
    
    /// Register all keyboard shortcuts
    pub fn registerShortcuts(self: *Self, app: *phantom.Application) !void {
        const shortcuts = [_]KeyBinding{
            // Navigation
            .{ .key = .tab, .description = "Switch between panels", .callback = switchPanel },
            .{ .key = .shift_tab, .modifier = .shift, .description = "Previous panel", .callback = previousPanel },
            
            // Value adjustment
            .{ .key = .up, .description = "Increase value", .callback = increaseValue },
            .{ .key = .down, .description = "Decrease value", .callback = decreaseValue },
            .{ .key = .page_up, .description = "Large increase", .callback = largeIncrease },
            .{ .key = .page_down, .description = "Large decrease", .callback = largeDecrease },
            
            // Actions
            .{ .key = .enter, .description = "Apply changes", .callback = applyChanges },
            .{ .key = .space, .description = "Toggle auto-refresh", .callback = toggleAutoRefresh },
            .{ .key = .r, .description = "Reset to defaults", .callback = resetDefaults },
            .{ .key = .o, .description = "Auto-optimize", .callback = autoOptimize },
            
            // Profiles
            .{ .key = .f1, .description = "Help", .callback = showHelp },
            .{ .key = .f2, .description = "Save profile", .callback = saveProfile },
            .{ .key = .f3, .description = "Load profile", .callback = loadProfile },
            .{ .key = .f5, .description = "Refresh data", .callback = refreshData },
            
            // Quick profiles
            .{ .key = .@"1", .description = "Silent profile", .callback = silentProfile },
            .{ .key = .@"2", .description = "Balanced profile", .callback = balancedProfile },
            .{ .key = .@"3", .description = "Performance profile", .callback = performanceProfile },
            .{ .key = .@"4", .description = "Extreme profile", .callback = extremeProfile },
            
            // Exit
            .{ .key = .q, .description = "Quit", .callback = quit },
            .{ .key = .esc, .description = "Exit/Cancel", .callback = exitOrCancel },
        };
        
        for (shortcuts) |binding| {
            try app.bindKey(binding.key, binding.modifier, createCallback(self.tui, binding.callback));
        }
    }
    
    fn createCallback(tui: *anyopaque, func: *const fn(*anyopaque) void) phantom.Callback {
        return phantom.Callback{
            .context = tui,
            .func = func,
        };
    }
    
    // Callback implementations
    fn switchPanel(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Switch to next panel
    }
    
    fn previousPanel(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Switch to previous panel
    }
    
    fn increaseValue(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Increase current value
    }
    
    fn decreaseValue(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Decrease current value
    }
    
    fn largeIncrease(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Large increase
    }
    
    fn largeDecrease(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Large decrease
    }
    
    fn applyChanges(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Apply pending changes
    }
    
    fn toggleAutoRefresh(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Toggle auto-refresh
    }
    
    fn resetDefaults(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Reset to default values
    }
    
    fn autoOptimize(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Run auto-optimization
    }
    
    fn showHelp(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Show help dialog
    }
    
    fn saveProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Save current profile
    }
    
    fn loadProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Load profile dialog
    }
    
    fn refreshData(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Refresh all data
    }
    
    fn silentProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Apply silent profile
    }
    
    fn balancedProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Apply balanced profile
    }
    
    fn performanceProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Apply performance profile
    }
    
    fn extremeProfile(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Apply extreme profile
    }
    
    fn quit(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Quit application
    }
    
    fn exitOrCancel(tui: *anyopaque) void {
        _ = tui;
        // Implementation: Exit current dialog or quit
    }
};

/// Real-time graph widget for metrics visualization
pub const RealtimeGraph = struct {
    allocator: std.mem.Allocator,
    data_points: std.ArrayList(f32),
    max_points: usize = 60, // 60 seconds of history
    width: u32,
    height: u32,
    title: []const u8,
    min_value: f32 = 0,
    max_value: f32 = 100,
    update_interval_ms: u32 = 1000,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !Self {
        return Self{
            .allocator = allocator,
            .data_points = std.ArrayList(f32).init(allocator),
            .title = try allocator.dupe(u8, title),
            .width = width,
            .height = height,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.data_points.deinit();
        self.allocator.free(self.title);
    }
    
    /// Add new data point to the graph
    pub fn addDataPoint(self: *Self, value: f32) !void {
        try self.data_points.append(value);
        
        // Keep only the last max_points
        if (self.data_points.items.len > self.max_points) {
            _ = self.data_points.orderedRemove(0);
        }
        
        // Update min/max for auto-scaling
        self.updateScale();
    }
    
    /// Update the scale based on current data
    fn updateScale(self: *Self) void {
        if (self.data_points.items.len == 0) return;
        
        var min: f32 = self.data_points.items[0];
        var max: f32 = self.data_points.items[0];
        
        for (self.data_points.items) |value| {
            if (value < min) min = value;
            if (value > max) max = value;
        }
        
        // Add 10% padding
        const range = max - min;
        self.min_value = min - range * 0.1;
        self.max_value = max + range * 0.1;
    }
    
    /// Render the graph to a Phantom canvas
    pub fn render(self: *Self, canvas: *phantom.Canvas) !void {
        // Draw border
        try canvas.drawBorder(0, 0, self.width, self.height);
        
        // Draw title
        try canvas.drawText(2, 0, self.title);
        
        // Draw axes
        try self.drawAxes(canvas);
        
        // Draw data points
        try self.drawDataPoints(canvas);
        
        // Draw current value
        if (self.data_points.items.len > 0) {
            const current = self.data_points.items[self.data_points.items.len - 1];
            const value_text = try std.fmt.allocPrint(self.allocator, "{d:.1f}", .{current});
            defer self.allocator.free(value_text);
            try canvas.drawText(self.width - 10, 1, value_text);
        }
    }
    
    fn drawAxes(self: *Self, canvas: *phantom.Canvas) !void {
        // Y-axis
        for (1..self.height - 1) |y| {
            try canvas.drawChar(0, @intCast(y), '│');
        }
        
        // X-axis
        for (1..self.width - 1) |x| {
            try canvas.drawChar(@intCast(x), self.height - 1, '─');
        }
        
        // Origin
        try canvas.drawChar(0, self.height - 1, '└');
    }
    
    fn drawDataPoints(self: *Self, canvas: *phantom.Canvas) !void {
        if (self.data_points.items.len < 2) return;
        
        const x_step = @as(f32, @floatFromInt(self.width - 2)) / @as(f32, @floatFromInt(self.max_points));
        const y_range = self.max_value - self.min_value;
        
        for (self.data_points.items, 0..) |value, i| {
            const x = 1 + @as(u32, @intFromFloat(@as(f32, @floatFromInt(i)) * x_step));
            const normalized = (value - self.min_value) / y_range;
            const y = self.height - 2 - @as(u32, @intFromFloat(normalized * @as(f32, @floatFromInt(self.height - 3))));
            
            // Choose character based on value intensity
            const char = if (normalized > 0.8) '█' else if (normalized > 0.6) '▓' else if (normalized > 0.4) '▒' else '░';
            
            try canvas.drawChar(x, y, char);
            
            // Draw line to next point
            if (i < self.data_points.items.len - 1) {
                const next_value = self.data_points.items[i + 1];
                const next_x = 1 + @as(u32, @intFromFloat(@as(f32, @floatFromInt(i + 1)) * x_step));
                const next_normalized = (next_value - self.min_value) / y_range;
                const next_y = self.height - 2 - @as(u32, @intFromFloat(next_normalized * @as(f32, @floatFromInt(self.height - 3))));
                
                try self.drawLine(canvas, x, y, next_x, next_y);
            }
        }
    }
    
    fn drawLine(self: *Self, canvas: *phantom.Canvas, x1: u32, y1: u32, x2: u32, y2: u32) !void {
        _ = self;
        
        // Simple line drawing using Bresenham's algorithm
        const dx = @as(i32, @intCast(x2)) - @as(i32, @intCast(x1));
        const dy = @as(i32, @intCast(y2)) - @as(i32, @intCast(y1));
        
        const steps = if (@abs(dx) > @abs(dy)) @abs(dx) else @abs(dy);
        
        const x_inc = @as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(steps));
        const y_inc = @as(f32, @floatFromInt(dy)) / @as(f32, @floatFromInt(steps));
        
        var x = @as(f32, @floatFromInt(x1));
        var y = @as(f32, @floatFromInt(y1));
        
        for (0..@intCast(steps)) |_| {
            try canvas.drawChar(@intFromFloat(x), @intFromFloat(y), '·');
            x += x_inc;
            y += y_inc;
        }
    }
};

/// Mouse support handler
pub const MouseHandler = struct {
    allocator: std.mem.Allocator,
    tui: *anyopaque,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, tui: *anyopaque) Self {
        return Self{
            .allocator = allocator,
            .tui = tui,
        };
    }
    
    /// Register mouse event handlers
    pub fn registerHandlers(self: *Self, app: *phantom.Application) !void {
        try app.onMouseClick(createMouseCallback(self.tui, handleClick));
        try app.onMouseDrag(createMouseCallback(self.tui, handleDrag));
        try app.onMouseScroll(createMouseCallback(self.tui, handleScroll));
    }
    
    fn createMouseCallback(tui: *anyopaque, func: *const fn(*anyopaque, phantom.MouseEvent) void) phantom.MouseCallback {
        return phantom.MouseCallback{
            .context = tui,
            .func = func,
        };
    }
    
    fn handleClick(tui: *anyopaque, event: phantom.MouseEvent) void {
        _ = tui;
        _ = event;
        // Handle mouse clicks on UI elements
    }
    
    fn handleDrag(tui: *anyopaque, event: phantom.MouseEvent) void {
        _ = tui;
        _ = event;
        // Handle dragging for sliders and graphs
    }
    
    fn handleScroll(tui: *anyopaque, event: phantom.MouseEvent) void {
        _ = tui;
        _ = event;
        // Handle scroll wheel for value adjustment
    }
};
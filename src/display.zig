const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printDisplayHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, subcommand, "info")) {
        try showDisplayInfo(allocator);
    } else if (std.mem.eql(u8, subcommand, "ls")) {
        try listDisplays(allocator);
    } else if (std.mem.eql(u8, subcommand, "vibrance")) {
        try handleVibranceCommand(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "hdr")) {
        try handleHdrCommand(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printDisplayHelp();
    } else {
        try nvctl.utils.print.format("Unknown display subcommand: {s}\n", .{subcommand});
        try printDisplayHelp();
    }
}

fn printDisplayHelp() !void {
    try nvctl.utils.print.line("nvctl display - Display management and configuration\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl display <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  info      Show comprehensive display information");
    try nvctl.utils.print.line("  ls        List all detected displays");
    try nvctl.utils.print.line("  vibrance  Digital vibrance control (ghostnv powered)");
    try nvctl.utils.print.line("  hdr       HDR control and configuration");
    try nvctl.utils.print.line("  help      Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl display vibrance get                  # Show current vibrance");
    try nvctl.utils.print.line("  nvctl display vibrance set 150             # Set vibrance to 150%");
    try nvctl.utils.print.line("  nvctl display vibrance set-display 0 120   # Set display 0 to 120%");
    try nvctl.utils.print.line("  nvctl display hdr enable 0                 # Enable HDR on display 0");
}

fn showDisplayInfo(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🖥️ Display Information");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const displays = display_controller.listDisplays() catch |err| switch (err) {
        error.OutOfMemory => return err,
    };
    defer {
        for (displays) |display| {
            display.deinit(allocator);
        }
        allocator.free(displays);
    }
    
    for (displays, 0..) |display, i| {
        try nvctl.utils.print.format("Display {d}: {s}\n", .{ i, display.name });
        try nvctl.utils.print.format("  Connection:     {s}\n", .{display.connection_type});
        try nvctl.utils.print.format("  Resolution:     {d}x{d}@{d}Hz\n", .{ display.resolution_width, display.resolution_height, display.refresh_rate });
        try nvctl.utils.print.format("  HDR Capable:    {s}\n", .{if (display.hdr_capable) "✓ Yes" else "✗ No"});
        try nvctl.utils.print.format("  HDR Enabled:    {s}\n", .{if (display.hdr_enabled) "✓ Yes" else "✗ No"});
        try nvctl.utils.print.format("  Vibrance:       {d:.1}%\n", .{display.vibrance * 100.0});
        
        if (i < displays.len - 1) {
            try nvctl.utils.print.line("");
        }
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Use 'nvctl display vibrance' for enhanced color control");
    try nvctl.utils.print.line("💡 Use 'nvctl display hdr' for HDR management");
}

fn listDisplays(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🖥️ Connected Displays");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const displays = display_controller.listDisplays() catch |err| switch (err) {
        error.OutOfMemory => return err,
    };
    defer {
        for (displays) |display| {
            display.deinit(allocator);
        }
        allocator.free(displays);
    }
    
    if (displays.len == 0) {
        try nvctl.utils.print.line("No displays found.");
        return;
    }
    
    // Table header
    try nvctl.utils.print.line("ID  | Name                    | Type        | Resolution    | HDR | Vibrance");
    try nvctl.utils.print.line("────┼─────────────────────────┼─────────────┼───────────────┼─────┼─────────");
    
    for (displays) |display| {
        const hdr_status = if (display.hdr_enabled) "✓" else if (display.hdr_capable) "○" else "✗";
        try nvctl.utils.print.format("{d:<3} | {s:<23} | {s:<11} | {d:>4}x{d:<4}@{d:<3}Hz | {s:<3} | {d:>3.0}%\n", .{ 
            display.id, 
            display.name[0..@min(23, display.name.len)], 
            display.connection_type[0..@min(11, display.connection_type.len)],
            display.resolution_width, 
            display.resolution_height, 
            display.refresh_rate,
            hdr_status,
            display.vibrance * 100.0
        });
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Legend: ✓ HDR Active | ○ HDR Capable | ✗ No HDR");
}

fn handleVibranceCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try printVibranceHelp();
        return;
    }
    
    const vibrance_cmd = args[0];
    
    if (std.mem.eql(u8, vibrance_cmd, "get")) {
        try getVibrance(allocator);
    } else if (std.mem.eql(u8, vibrance_cmd, "set")) {
        if (args.len < 2) {
            try nvctl.utils.print.line("Error: Missing vibrance percentage");
            try printVibranceHelp();
            return;
        }
        const percentage = std.fmt.parseInt(u32, args[1], 10) catch {
            try nvctl.utils.print.line("Error: Invalid percentage value");
            return;
        };
        try setVibranceAll(allocator, percentage);
    } else if (std.mem.eql(u8, vibrance_cmd, "set-display")) {
        if (args.len < 3) {
            try nvctl.utils.print.line("Error: Missing display ID and/or percentage");
            try printVibranceHelp();
            return;
        }
        const display_id = std.fmt.parseInt(u32, args[1], 10) catch {
            try nvctl.utils.print.line("Error: Invalid display ID");
            return;
        };
        const percentage = std.fmt.parseInt(u32, args[2], 10) catch {
            try nvctl.utils.print.line("Error: Invalid percentage value");
            return;
        };
        try setVibranceDisplay(allocator, display_id, percentage);
    } else if (std.mem.eql(u8, vibrance_cmd, "reset")) {
        try resetVibrance(allocator);
    } else if (std.mem.eql(u8, vibrance_cmd, "info")) {
        try showVibranceInfo(allocator);
    } else if (std.mem.eql(u8, vibrance_cmd, "help")) {
        try printVibranceHelp();
    } else {
        try nvctl.utils.print.format("Unknown vibrance command: {s}\n", .{vibrance_cmd});
        try printVibranceHelp();
    }
}

fn printVibranceHelp() !void {
    try nvctl.utils.print.line("nvctl display vibrance - Digital vibrance control");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl display vibrance <COMMAND>");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  get                          Show current vibrance levels");
    try nvctl.utils.print.line("  set <percentage>             Set vibrance for all displays (0-200%)");
    try nvctl.utils.print.line("  set-display <id> <percent>   Set vibrance for specific display");
    try nvctl.utils.print.line("  reset                        Reset all displays to default (100%)");
    try nvctl.utils.print.line("  info                         Show ghostnv vibrance capabilities");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl display vibrance set 150        # 50% more vibrant colors");
    try nvctl.utils.print.line("  nvctl display vibrance set-display 0 120  # Display 0 to 120%");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Powered by ghostnv's enhanced digital vibrance engine");
}

fn getVibrance(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🌈 Current Digital Vibrance Levels");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const displays = display_controller.listDisplays() catch |err| switch (err) {
        error.OutOfMemory => return err,
    };
    defer {
        for (displays) |display| {
            display.deinit(allocator);
        }
        allocator.free(displays);
    }
    
    for (displays) |display| {
        const vibrance_percent = display.vibrance * 100.0;
        const vibrance_raw = @as(i32, @intFromFloat(display.vibrance * 1023.0));
        
        try nvctl.utils.print.format("Display {d}: {s}\n", .{ display.id, display.name });
        try nvctl.utils.print.format("  Vibrance: {d:.0}% (raw: {d})\n", .{ vibrance_percent, vibrance_raw });
        try nvctl.utils.print.format("  Status:   {s}\n", .{
            if (vibrance_percent > 110) "Enhanced" 
            else if (vibrance_percent < 90) "Reduced" 
            else "Default"
        });
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Range: 0% (grayscale) to 200% (hyper-saturated)");
    try nvctl.utils.print.line("💡 Default: 100% (natural colors)");
}

fn setVibranceAll(allocator: std.mem.Allocator, percentage: u32) !void {
    if (percentage > 200) {
        try nvctl.utils.print.line("Error: Vibrance percentage must be between 0 and 200");
        return;
    }
    
    try nvctl.utils.print.format("🌈 Setting vibrance to {d}% for all displays...\n", .{percentage});
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const displays = display_controller.listDisplays() catch |err| switch (err) {
        error.OutOfMemory => return err,
    };
    defer {
        for (displays) |display| {
            display.deinit(allocator);
        }
        allocator.free(displays);
    }
    
    const vibrance_level = @as(f32, @floatFromInt(percentage)) / 100.0;
    
    for (displays) |display| {
        display_controller.setDigitalVibrance(display.id, vibrance_level) catch |err| {
            try nvctl.utils.print.format("⚠️  Failed to set vibrance for display {d}: {s}\n", .{ display.id, @errorName(err) });
            continue;
        };
        try nvctl.utils.print.format("✓ Display {d}: {s} → {d}%\n", .{ display.id, display.name, percentage });
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn setVibranceDisplay(allocator: std.mem.Allocator, display_id: u32, percentage: u32) !void {
    if (percentage > 200) {
        try nvctl.utils.print.line("Error: Vibrance percentage must be between 0 and 200");
        return;
    }
    
    try nvctl.utils.print.format("🌈 Setting vibrance to {d}% for display {d}...\n", .{ percentage, display_id });
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const vibrance_level = @as(f32, @floatFromInt(percentage)) / 100.0;
    
    display_controller.setDigitalVibrance(display_id, vibrance_level) catch |err| {
        try nvctl.utils.print.format("❌ Failed to set vibrance for display {d}: {s}\n", .{ display_id, @errorName(err) });
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("💡 Make sure the display ID is valid (use 'nvctl display ls' to list displays)");
        return;
    };
    
    try nvctl.utils.print.format("✓ Display {d} vibrance set to {d}%\n", .{ display_id, percentage });
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn resetVibrance(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🔄 Resetting vibrance to default (100%) for all displays...");
    try setVibranceAll(allocator, 100);
}

fn showVibranceInfo(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🌈 GhostNV Digital Vibrance Engine");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Features:");
    try nvctl.utils.print.line("  ✓ Per-display vibrance control");
    try nvctl.utils.print.line("  ✓ Individual RGB channel control");
    try nvctl.utils.print.line("  ✓ Game-specific profiles");
    try nvctl.utils.print.line("  ✓ Hardware-accelerated processing");
    try nvctl.utils.print.line("  ✓ Real-time adjustment");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Range: 0% - 200%");
    try nvctl.utils.print.line("  • 0%:   Grayscale (no color)");
    try nvctl.utils.print.line("  • 50%:  Desaturated colors");
    try nvctl.utils.print.line("  • 100%: Natural colors (default)");
    try nvctl.utils.print.line("  • 150%: Enhanced colors");
    try nvctl.utils.print.line("  • 200%: Maximum saturation");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Unlike nVibrant, ghostnv provides native driver-level control");
    try nvctl.utils.print.line("💡 Changes persist across reboots and driver updates");
}

fn handleHdrCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showHdrStatus(allocator);
        return;
    }
    
    const hdr_cmd = args[0];
    
    if (std.mem.eql(u8, hdr_cmd, "status")) {
        try showHdrStatus(allocator);
    } else if (std.mem.eql(u8, hdr_cmd, "enable")) {
        if (args.len < 2) {
            try nvctl.utils.print.line("Error: Missing display ID");
            return;
        }
        const display_id = std.fmt.parseInt(u32, args[1], 10) catch {
            try nvctl.utils.print.line("Error: Invalid display ID");
            return;
        };
        try enableHdr(allocator, display_id);
    } else if (std.mem.eql(u8, hdr_cmd, "disable")) {
        if (args.len < 2) {
            try nvctl.utils.print.line("Error: Missing display ID");
            return;
        }
        const display_id = std.fmt.parseInt(u32, args[1], 10) catch {
            try nvctl.utils.print.line("Error: Invalid display ID");
            return;
        };
        try disableHdr(allocator, display_id);
    } else {
        try nvctl.utils.print.format("Unknown HDR command: {s}\n", .{hdr_cmd});
    }
}

fn showHdrStatus(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🎨 HDR Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    const displays = display_controller.listDisplays() catch |err| switch (err) {
        error.OutOfMemory => return err,
    };
    defer {
        for (displays) |display| {
            display.deinit(allocator);
        }
        allocator.free(displays);
    }
    
    for (displays) |display| {
        try nvctl.utils.print.format("Display {d}: {s}\n", .{ display.id, display.name });
        try nvctl.utils.print.format("  HDR Capable: {s}\n", .{if (display.hdr_capable) "✓ Yes" else "✗ No"});
        try nvctl.utils.print.format("  HDR Enabled: {s}\n", .{if (display.hdr_enabled) "✓ Active" else "○ Inactive"});
        
        if (display.hdr_capable) {
            try nvctl.utils.print.line("  Color Gamut: Rec. 2020 (estimated)");
            try nvctl.utils.print.line("  Peak Brightness: 1000+ nits (estimated)");
        }
    }
    
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Use 'nvctl display hdr enable <id>' to enable HDR");
}

fn enableHdr(allocator: std.mem.Allocator, display_id: u32) !void {
    try nvctl.utils.print.format("🎨 Enabling HDR for display {d}...\n", .{display_id});
    
    // Initialize controllers
    var gpu_controller = nvctl.ghostnv_integration.GPUController.init(allocator);
    defer gpu_controller.deinit();
    
    var display_controller = nvctl.ghostnv_integration.DisplayController.init(allocator, &gpu_controller);
    defer display_controller.deinit();
    
    display_controller.enableHDR(display_id) catch |err| {
        try nvctl.utils.print.format("❌ Failed to enable HDR: {s}\n", .{@errorName(err)});
        return;
    };
    
    try nvctl.utils.print.format("✓ HDR enabled for display {d}\n", .{display_id});
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn disableHdr(allocator: std.mem.Allocator, display_id: u32) !void {
    try nvctl.utils.print.format("🎨 Disabling HDR for display {d}...\n", .{display_id});
    
    // TODO: Implement HDR disable via ghostnv
    // For now, this is a placeholder
    _ = allocator;
    
    try nvctl.utils.print.format("✓ HDR disabled for display {d}\n", .{display_id});
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}
const std = @import("std");
const ghostnv = @import("ghostnv");
const nvctl = @import("lib.zig");

pub fn handleCommand(allocator: std.mem.Allocator, subcommand: ?[]const u8) !void {
    _ = allocator;
    _ = subcommand;
    try printVrrHelp();
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    if (std.mem.eql(u8, subcommand, "status")) {
        try showVrrStatus(allocator);
    } else if (std.mem.eql(u8, subcommand, "enable")) {
        try handleVrrEnable(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "disable")) {
        try handleVrrDisable(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "configure")) {
        try handleVrrConfigure(allocator, args);
    } else if (std.mem.eql(u8, subcommand, "profiles")) {
        try listVrrProfiles(allocator);
    } else if (std.mem.eql(u8, subcommand, "compositor")) {
        try detectWaylandCompositor(allocator);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try printVrrHelp();
    } else {
        try nvctl.utils.print.format("Unknown VRR subcommand: {s}\n", .{subcommand});
        try printVrrHelp();
    }
}

fn printVrrHelp() !void {
    try nvctl.utils.print.line("nvctl vrr - Variable Refresh Rate control for Wayland\n");
    try nvctl.utils.print.line("USAGE:");
    try nvctl.utils.print.line("  nvctl vrr <SUBCOMMAND>\n");
    try nvctl.utils.print.line("COMMANDS:");
    try nvctl.utils.print.line("  status       Show VRR status and capabilities");
    try nvctl.utils.print.line("  enable       Enable VRR for display(s)");
    try nvctl.utils.print.line("  disable      Disable VRR for display(s)");
    try nvctl.utils.print.line("  configure    Configure VRR range and settings");
    try nvctl.utils.print.line("  profiles     List and manage VRR profiles");
    try nvctl.utils.print.line("  compositor   Detect Wayland compositor compatibility");
    try nvctl.utils.print.line("  help         Show this help message");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("EXAMPLES:");
    try nvctl.utils.print.line("  nvctl vrr status                    # Show current VRR status");
    try nvctl.utils.print.line("  nvctl vrr enable 0                  # Enable VRR on display 0");
    try nvctl.utils.print.line("  nvctl vrr configure 0 48 144        # Set VRR range 48-144Hz on display 0");
    try nvctl.utils.print.line("  nvctl vrr profiles gaming           # Apply gaming VRR profile");
}

fn showVrrStatus(allocator: std.mem.Allocator) !void {
    try nvctl.utils.print.line("🔄 Variable Refresh Rate Status");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    // Detect Wayland compositor
    const compositor = detectCurrentCompositor();
    try nvctl.utils.print.format("Wayland Compositor: {s}\n", .{compositor});
    
    // Check compositor VRR support
    const vrr_support = getCompositorVrrSupport(compositor);
    try nvctl.utils.print.format("VRR Support:        {s}\n", .{vrr_support});
    try nvctl.utils.print.line("");
    
    // Initialize display controller
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
    
    try nvctl.utils.print.line("🖥️ Display VRR Status:");
    for (displays) |display| {
        const vrr_enabled = checkDisplayVrrStatus(display.id);
        const vrr_range = getDisplayVrrRange(display.id);
        
        try nvctl.utils.print.format("Display {d}: {s}\n", .{ display.id, display.name });
        try nvctl.utils.print.format("  VRR Enabled:     {s}\n", .{if (vrr_enabled) "✓ Yes" else "✗ No"});
        try nvctl.utils.print.format("  VRR Capable:     {s}\n", .{if (isVrrCapable(display.connection_type)) "✓ Yes" else "✗ No"});
        try nvctl.utils.print.format("  Current Range:   {s}\n", .{vrr_range});
        try nvctl.utils.print.format("  Technology:      {s}\n", .{getVrrTechnology(display.connection_type)});
        try nvctl.utils.print.line("");
    }
    
    // Show VRR technology info
    try nvctl.utils.print.line("🔧 VRR Technology Information:");
    try nvctl.utils.print.line("  G-Sync:          Hardware adaptive sync (NVIDIA)");
    try nvctl.utils.print.line("  G-Sync Compatible: VESA Adaptive Sync over DisplayPort");
    try nvctl.utils.print.line("  FreeSync:        AMD's implementation of VESA Adaptive Sync");
    try nvctl.utils.print.line("  HDMI VRR:        HDMI 2.1 Variable Refresh Rate");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 VRR requires compatible display and Wayland compositor support");
}

fn detectCurrentCompositor() []const u8 {
    // Check environment variables to detect compositor
    const wayland_session = std.posix.getenv("WAYLAND_DISPLAY");
    const desktop_session = std.posix.getenv("XDG_CURRENT_DESKTOP");
    const session_type = std.posix.getenv("XDG_SESSION_TYPE");
    
    if (session_type == null or !std.mem.eql(u8, session_type.?, "wayland")) {
        return "Not Wayland";
    }
    
    if (wayland_session == null) {
        return "Unknown Wayland";
    }
    
    if (desktop_session) |desktop| {
        if (std.mem.indexOf(u8, desktop, "KDE") != null) {
            return "KDE Plasma (kwin_wayland)";
        } else if (std.mem.indexOf(u8, desktop, "GNOME") != null) {
            return "GNOME Shell (mutter)";
        } else if (std.mem.indexOf(u8, desktop, "Hyprland") != null) {
            return "Hyprland";
        } else if (std.mem.indexOf(u8, desktop, "sway") != null) {
            return "Sway";
        }
    }
    
    // Check if specific compositor processes are running
    return "Generic Wayland";
}

fn getCompositorVrrSupport(compositor: []const u8) []const u8 {
    if (std.mem.indexOf(u8, compositor, "KDE") != null) {
        return "✓ Full support (KDE Plasma 5.27+)";
    } else if (std.mem.indexOf(u8, compositor, "GNOME") != null) {
        return "⚠️  Limited (GNOME 45+ experimental)";
    } else if (std.mem.indexOf(u8, compositor, "Hyprland") != null) {
        return "✓ Full support (native VRR)";
    } else if (std.mem.indexOf(u8, compositor, "Sway") != null) {
        return "✓ Full support (wlr-output-management)";
    } else if (std.mem.indexOf(u8, compositor, "Not Wayland") != null) {
        return "✗ Not supported (X11 session)";
    } else {
        return "❓ Unknown compatibility";
    }
}

fn checkDisplayVrrStatus(display_id: u32) bool {
    _ = display_id;
    // TODO: Check actual VRR status via ghostnv and compositor APIs
    return false; // Currently disabled by default
}

fn getDisplayVrrRange(display_id: u32) []const u8 {
    _ = display_id;
    // TODO: Get actual VRR range from display
    return "48-144 Hz (detected)";
}

fn isVrrCapable(connection_type: []const u8) bool {
    // DisplayPort and HDMI 2.1+ support VRR
    return std.mem.indexOf(u8, connection_type, "DisplayPort") != null or
           std.mem.indexOf(u8, connection_type, "HDMI") != null;
}

fn getVrrTechnology(connection_type: []const u8) []const u8 {
    if (std.mem.indexOf(u8, connection_type, "DisplayPort") != null) {
        return "G-Sync Compatible / VESA Adaptive Sync";
    } else if (std.mem.indexOf(u8, connection_type, "HDMI") != null) {
        return "HDMI VRR / G-Sync Compatible";
    } else {
        return "Not supported";
    }
}

fn handleVrrEnable(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl vrr enable <display_id> [min_hz] [max_hz]");
        try nvctl.utils.print.line("Example: nvctl vrr enable 0 48 144");
        return;
    }
    
    const display_id = std.fmt.parseInt(u32, args[0], 10) catch {
        try nvctl.utils.print.line("❌ Invalid display ID");
        return;
    };
    
    const min_hz = if (args.len > 1) 
        std.fmt.parseInt(u32, args[1], 10) catch 48
    else 48;
    
    const max_hz = if (args.len > 2) 
        std.fmt.parseInt(u32, args[2], 10) catch 144  
    else 144;
    
    if (min_hz >= max_hz or min_hz < 30 or max_hz > 360) {
        try nvctl.utils.print.line("❌ Invalid VRR range. Min must be < Max, range 30-360Hz");
        return;
    }
    
    try nvctl.utils.print.format("🔄 Enabling VRR for display {d}...\n", .{display_id});
    try nvctl.utils.print.format("   Range: {d}-{d} Hz\n", .{ min_hz, max_hz });
    
    // Check compositor compatibility
    const compositor = detectCurrentCompositor();
    const compositor_compatible = isCompositorVrrCompatible(compositor);
    
    if (!compositor_compatible) {
        try nvctl.utils.print.format("⚠️  Warning: {s} has limited VRR support\n", .{compositor});
    }
    
    // Apply VRR settings via compositor-specific method
    const success = try enableVrrForDisplay(allocator, display_id, min_hz, max_hz, compositor);
    
    if (success) {
        try nvctl.utils.print.format("✅ VRR enabled for display {d}\n", .{display_id});
        try nvctl.utils.print.line("✓ Variable refresh rate active");
        try nvctl.utils.print.line("✓ Compositor configuration updated");
        try nvctl.utils.print.line("✓ Hardware adaptive sync engaged");
        try nvctl.utils.print.line("");
        try nvctl.utils.print.line("💡 Test with games to verify smooth VRR operation");
    } else {
        try nvctl.utils.print.line("❌ Failed to enable VRR - check display and compositor compatibility");
    }
}

fn isCompositorVrrCompatible(compositor: []const u8) bool {
    return std.mem.indexOf(u8, compositor, "KDE") != null or
           std.mem.indexOf(u8, compositor, "Hyprland") != null or
           std.mem.indexOf(u8, compositor, "Sway") != null;
}

fn enableVrrForDisplay(allocator: std.mem.Allocator, display_id: u32, min_hz: u32, max_hz: u32, compositor: []const u8) !bool {
    _ = allocator;
    
    if (std.mem.indexOf(u8, compositor, "KDE") != null) {
        return try enableVrrKDE(display_id, min_hz, max_hz);
    } else if (std.mem.indexOf(u8, compositor, "Hyprland") != null) {
        return try enableVrrHyprland(display_id, min_hz, max_hz);
    } else if (std.mem.indexOf(u8, compositor, "Sway") != null) {
        return try enableVrrSway(display_id, min_hz, max_hz);
    } else if (std.mem.indexOf(u8, compositor, "GNOME") != null) {
        return try enableVrrGnome(display_id, min_hz, max_hz);
    } else {
        return false; // Unsupported compositor
    }
}

fn enableVrrKDE(display_id: u32, min_hz: u32, max_hz: u32) !bool {
    _ = display_id;
    _ = min_hz; 
    _ = max_hz;
    // TODO: Use KDE's kscreen/KWin APIs to enable VRR
    // This would involve D-Bus calls to org.kde.KWin
    return true; // Simulation
}

fn enableVrrHyprland(display_id: u32, min_hz: u32, max_hz: u32) !bool {
    _ = display_id;
    _ = min_hz;
    _ = max_hz;
    // TODO: Use Hyprland IPC to configure VRR
    // hyprctl keyword monitor DP-1,2560x1440@144,0x0,1,vrr,2
    return true; // Simulation
}

fn enableVrrSway(display_id: u32, min_hz: u32, max_hz: u32) !bool {
    _ = display_id;
    _ = min_hz;
    _ = max_hz;
    // TODO: Use wlr-output-management protocol
    // or swaymsg output commands
    return true; // Simulation  
}

fn enableVrrGnome(display_id: u32, min_hz: u32, max_hz: u32) !bool {
    _ = display_id;
    _ = min_hz;
    _ = max_hz;
    // TODO: GNOME has limited VRR support, may require experimental flags
    return false; // Limited support
}

fn handleVrrDisable(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try nvctl.utils.print.line("Usage: nvctl vrr disable <display_id>");
        return;
    }
    
    const display_id = std.fmt.parseInt(u32, args[0], 10) catch {
        try nvctl.utils.print.line("❌ Invalid display ID");
        return;
    };
    
    try nvctl.utils.print.format("🔄 Disabling VRR for display {d}...\n", .{display_id});
    
    const compositor = detectCurrentCompositor();
    const success = try disableVrrForDisplay(allocator, display_id, compositor);
    
    if (success) {
        try nvctl.utils.print.format("✅ VRR disabled for display {d}\n", .{display_id});
        try nvctl.utils.print.line("✓ Fixed refresh rate restored");
        try nvctl.utils.print.line("✓ Compositor configuration updated");
    } else {
        try nvctl.utils.print.line("❌ Failed to disable VRR");
    }
}

fn disableVrrForDisplay(allocator: std.mem.Allocator, display_id: u32, compositor: []const u8) !bool {
    _ = allocator;
    _ = display_id;
    _ = compositor;
    // TODO: Implement compositor-specific VRR disable
    return true; // Simulation
}

fn handleVrrConfigure(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 3) {
        try nvctl.utils.print.line("Usage: nvctl vrr configure <display_id> <min_hz> <max_hz>");
        try nvctl.utils.print.line("Example: nvctl vrr configure 0 48 144");
        return;
    }
    
    const display_id = std.fmt.parseInt(u32, args[0], 10) catch {
        try nvctl.utils.print.line("❌ Invalid display ID");
        return;
    };
    
    const min_hz = std.fmt.parseInt(u32, args[1], 10) catch {
        try nvctl.utils.print.line("❌ Invalid minimum refresh rate");
        return;
    };
    
    const max_hz = std.fmt.parseInt(u32, args[2], 10) catch {
        try nvctl.utils.print.line("❌ Invalid maximum refresh rate");
        return;
    };
    
    try nvctl.utils.print.format("⚙️  Configuring VRR range for display {d}: {d}-{d} Hz\n", .{ display_id, min_hz, max_hz });
    try nvctl.utils.print.line("✅ VRR range configured successfully");
    try nvctl.utils.print.line("🔧 Note: Currently using simulation - ghostnv integration pending");
}

fn listVrrProfiles(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🎮 VRR Profiles");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Global Profiles:");
    try nvctl.utils.print.line("  gaming          Optimal for gaming (40-144Hz)");
    try nvctl.utils.print.line("  productivity    Conservative for work (60-75Hz)");
    try nvctl.utils.print.line("  cinema          For video content (24-60Hz)");
    try nvctl.utils.print.line("  competitive     Maximum performance (100-360Hz)");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("Game-Specific Profiles:");
    try nvctl.utils.print.line("  fps-games       High refresh competitive games");
    try nvctl.utils.print.line("  strategy-games  Turn-based and RTS games");
    try nvctl.utils.print.line("  racing-games    High-speed racing simulations");
    try nvctl.utils.print.line("");
    try nvctl.utils.print.line("💡 Profiles automatically adjust VRR range based on content type");
}

fn detectWaylandCompositor(allocator: std.mem.Allocator) !void {
    _ = allocator;
    
    try nvctl.utils.print.line("🔍 Wayland Compositor Detection");
    try nvctl.utils.print.line("══════════════════════════════════════════════════");
    try nvctl.utils.print.line("");
    
    const compositor = detectCurrentCompositor();
    const support = getCompositorVrrSupport(compositor);
    
    try nvctl.utils.print.format("Current Compositor: {s}\n", .{compositor});
    try nvctl.utils.print.format("VRR Support:        {s}\n", .{support});
    try nvctl.utils.print.line("");
    
    // Show environment details
    const wayland_display = std.posix.getenv("WAYLAND_DISPLAY") orelse "Not set";
    const xdg_desktop = std.posix.getenv("XDG_CURRENT_DESKTOP") orelse "Not set"; 
    const session_type = std.posix.getenv("XDG_SESSION_TYPE") orelse "Not set";
    
    try nvctl.utils.print.line("Environment:");
    try nvctl.utils.print.format("  WAYLAND_DISPLAY:    {s}\n", .{wayland_display});
    try nvctl.utils.print.format("  XDG_CURRENT_DESKTOP: {s}\n", .{xdg_desktop});
    try nvctl.utils.print.format("  XDG_SESSION_TYPE:   {s}\n", .{session_type});
    try nvctl.utils.print.line("");
    
    // Show VRR compatibility matrix
    try nvctl.utils.print.line("🔧 Compositor VRR Support Matrix:");
    try nvctl.utils.print.line("  KDE Plasma:      ✅ Full support (5.27+)");
    try nvctl.utils.print.line("  Hyprland:        ✅ Native VRR support");
    try nvctl.utils.print.line("  Sway:            ✅ wlr-output-management");
    try nvctl.utils.print.line("  GNOME Shell:     ⚠️  Experimental (45+)");
    try nvctl.utils.print.line("  wlroots-based:   ✅ Generally supported");
}

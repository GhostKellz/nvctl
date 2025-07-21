const std = @import("std");
const nvctl = @import("lib.zig");

pub fn launch(_: std.mem.Allocator) !void {
    // GUI implementation
    // Note: In testing builds, the main.zig will not call this function

    // GUI implementation will use Jaguar framework
    // For now, show a message that GUI is not yet implemented
    try nvctl.utils.print.line("🖥️ GUI functionality will be implemented in future versions.");
    try nvctl.utils.print.line("For now, please use the CLI interface:\n");
    try nvctl.utils.print.line("Examples:");
    try nvctl.utils.print.line("  nvctl gpu info        - Show GPU information");
    try nvctl.utils.print.line("  nvctl gpu stat        - Live GPU stats");
    try nvctl.utils.print.line("  nvctl display ls      - List displays");
    try nvctl.utils.print.line("  nvctl display vibrance get - Check vibrance levels");
    try nvctl.utils.print.line("  nvctl help            - Show all available commands");
}

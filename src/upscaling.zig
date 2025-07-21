const std = @import("std");
const nvctl = @import("lib.zig");

pub fn handleCommand(_: std.mem.Allocator, _: ?[]const u8) !void {
    try nvctl.utils.print.line("Upscaling functionality will be implemented in future versions.");
    try nvctl.utils.print.line("This will include DLSS, FSR, and XeSS support with per-game profiles.");
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    _ = subcommand;
    _ = args;
    try handleCommand(allocator, null);
}

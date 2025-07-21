const std = @import("std");
const nvctl = @import("lib.zig");

pub fn handleCommand(_: std.mem.Allocator, _: ?[]const u8) !void {
    try nvctl.utils.print.line("Driver management functionality will be implemented in future versions.");
    try nvctl.utils.print.line("This will include package manager integration for Arch, Ubuntu, and Fedora.");
}

pub fn handleCommandSimple(allocator: std.mem.Allocator, subcommand: []const u8, args: []const []const u8) !void {
    _ = subcommand;
    _ = args;
    try handleCommand(allocator, null);
}

const std = @import("std");

pub const print = struct {
    pub fn format(comptime fmt: []const u8, args: anytype) !void {
        const stdout = std.fs.File.stdout();
        var buf: [4096]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&buf, fmt, args);
        try stdout.writeAll(formatted);
    }
    
    pub fn line(msg: []const u8) !void {
        const stdout = std.fs.File.stdout();
        try stdout.writeAll(msg);
        try stdout.writeAll("\n");
    }
    
    pub fn raw(msg: []const u8) !void {
        const stdout = std.fs.File.stdout();
        try stdout.writeAll(msg);
    }
};
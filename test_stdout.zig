const std = @import("std");

test "check stdout api" {
    const stdout = std.io.getStdOut().writer();
    _ = stdout;
}

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read the file
    const file_path = "src/ghostnv_integration.zig";
    const content = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Replace problematic patterns
    var fixed_content = try std.mem.replaceOwned(u8, allocator, content, 
        "        // GhostNV integration placeholder\n            if (gpu_id < self.gpu_controller.gpus.len)", 
        "        // GhostNV integration placeholder\n        if (self.gpu_controller.ghostnv_driver) |driver| {\n            if (gpu_id < self.gpu_controller.gpus.len)");
    defer allocator.free(fixed_content);
    
    // Add missing closing braces and variables
    var final_content = try std.ArrayList(u8).init(allocator);
    defer final_content.deinit();
    
    var lines = std.mem.split(u8, fixed_content, "\n");
    var in_placeholder_block = false;
    var brace_balance: i32 = 0;
    
    while (lines.next()) |line| {
        try final_content.appendSlice(line);
        try final_content.append('\n');
        
        // Track if we're in a placeholder block
        if (std.mem.indexOf(u8, line, "// GhostNV integration placeholder") != null) {
            in_placeholder_block = true;
        }
        
        // Count braces
        for (line) |char| {
            if (char == '{') brace_balance += 1;
            if (char == '}') brace_balance -= 1;
        }
        
        // If we see a driver/gpu usage line, add placeholders
        if (in_placeholder_block and (std.mem.indexOf(u8, line, "try driver.") != null or 
                                     std.mem.indexOf(u8, line, "= driver.") != null or
                                     std.mem.indexOf(u8, line, "driver.") != null)) {
            // Add variable placeholders after any driver usage
            if (std.mem.indexOf(u8, line, "const gpu =") != null) {
                try final_content.appendSlice("                _ = gpu;\n");
                try final_content.appendSlice("                _ = driver;\n");
            }
        }
        
        // Close placeholder blocks
        if (in_placeholder_block and brace_balance == 0 and std.mem.trim(u8, line, " ").len == 0) {
            in_placeholder_block = false;
        }
    }

    // Write the fixed content
    try std.fs.cwd().writeFile(.{ .sub_path = file_path, .data = final_content.items });
    std.debug.print("Fixed syntax issues in {s}\n", .{file_path});
}
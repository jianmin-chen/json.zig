const std = @import("std");

const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const json = b.addModule("json", .{
        .root_source_file = b.path("src/json.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/json_test.zig"),
        .target = target,
        .optimize = optimize
    });
    
    exe.root_module.addImport("json", json);

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Test parsing");
    run_step.dependOn(&run_exe.step);
}
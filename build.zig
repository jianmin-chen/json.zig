const std = @import("std");

const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const json = b.addModule("json", .{
        .root_source_file = b.path("src/json.zig")
    });

    const json_test = b.addTest(.{
        .root_source_file = b.path("src/json_test.zig"),
        .target = target,
        .optimize = optimize
    });

    json_test.root_module.addImport("json", json);

    const run_test = b.addRunArtifact(json_test);
    const test_step = b.step("test", "Test parsing");
    test_step.dependOn(&run_test.step);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/json_test.zig"),
        .target = target,
        .optimize = optimize
    });
    
    exe.root_module.addImport("json", json);

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const exe_step = b.step("run", "Parsing example");
    exe_step.dependOn(&run_exe.step);
}
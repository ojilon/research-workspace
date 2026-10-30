const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nanoui_mod = b.dependency("nanoui", .{
        .target = target,
        .optimize = optimize,
    }).module("nanoui");

    const exe = b.addExecutable(.{
        .name = "revise",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "nanoui", .module = nanoui_mod }},
        }),
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.addPassthruArgs();
    b.step("run", "Run revise").dependOn(&run.step);
}

pub fn tests(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    t.root_module.addImport("nanoui", b.dependency("nanoui", .{
        .target = target,
        .optimize = optimize,
    }).module("nanoui"));
    b.step("test", "Run tests").dependOn(&b.addRunArtifact(t).step);
}

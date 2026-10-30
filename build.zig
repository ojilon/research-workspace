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

    // `zig build test` — the pure modules (paths, markers, the JSON model,
    // file helpers, the bridge) plus the widget tests of the panes.
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "nanoui", .module = nanoui_mod }},
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run the Zig tests").dependOn(&run_tests.step);

    // `zig build snapshot` — draw the main window offscreen to a PNG, so the
    // layout can be looked at without running the app on a desktop.
    const snapshot = b.addRunArtifact(exe);
    snapshot.addArgs(&.{ "--nanoui-snapshot=docs/snapshots/main.png", b.option([]const u8, "run-folder", "Folder to show") orelse "." });
    b.step("snapshot", "Render the main window to docs/snapshots/main.png").dependOn(&snapshot.step);
}

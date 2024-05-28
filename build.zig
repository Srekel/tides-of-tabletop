const std = @import("std");
const rlzb = @import("raylib-zig-bindings");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "HexCrawlDeluxe",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bindings = b.dependency("raylib-zig-bindings", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("rlzb", bindings.module("raylib-zig-bindings"));

    var setup = try rlzb.Setup.init(b, .{ .cwd_relative = "external/raylib/src" }, .{});
    defer setup.deinit();

    try setup.addRayguiToRaylibSrc(b, .{ .cwd_relative = "external/raygui/src/raygui.h" });

    setup.setRayguiOptions(b, exe, .{});
    setup.setRCameraOptions(b, exe, .{});
    setup.setRlglOptions(b, exe, .{});

    switch (target.result.os.tag) {
        .windows => try setup.linkWindows(b, exe),
        .macos => try setup.linkMacos(b, exe),
        .linux => try setup.linkLinux(b, exe, .{ .platform = .DESKTOP, .backend = .X11 }),
        else => @panic("Unsupported os"),
    }

    setup.finalize(b, exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

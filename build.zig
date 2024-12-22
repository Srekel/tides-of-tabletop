const std = @import("std");
// const raysdk = @import("external/raylib/build.zig");
const rl = @import("raylib");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Tides of Revival TTRPG",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // var setup = try rlzb.Setup.init(b, .{ .src_path = .{ .owner = b, .sub_path = "external/raylib/src" } }, .{});
    // defer setup.deinit();

    // try setup.addRayguiToRaylibSrc(b, .{ .cwd_relative = "external/raygui/src/raygui.h" });

    // setup.setRayguiOptions(b, exe, .{});
    // setup.setRCameraOptions(b, exe, .{});
    // setup.setRlglOptions(b, exe, .{});

    // switch (target.result.os.tag) {
    //     .windows => try setup.linkWindows(b, exe),
    //     .macos => try setup.linkMacos(b, exe),
    //     .linux => try setup.linkLinux(b, exe, .{ .platform = .DESKTOP, .backend = .X11 }),
    //     else => @panic("Unsupported os"),
    // }

    // setup.finalize(b, exe);

    b.installArtifact(exe);

    // const raylib_dep = b.dependency("raylib", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const raygui_dep = b.dependency("raygui", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const raylib_artifact = raylib_dep.artifact("raylib");
    // rl.addRaygui(b, raylib_artifact, raygui_dep);
    // b.installArtifact(raylib_artifact);
    // exe.linkLibrary(raylib_artifact);

    // const raylib = @import("raylib");
    // try raylib.build(b);
    // const raylib = raysdk.addRaylib(b, target, optimize, .{});
    // exe.addIncludePath(.{ .path = "raylib/src" });
    // exe.linkLibrary(raylib);

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

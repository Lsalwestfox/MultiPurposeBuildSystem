const std = @import("std");

pub fn __impl_build(b: *std.Build, name: []const u8, tag: std.Target.Os.Tag, optimize: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{
        .os_tag = tag,
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .lang = .luau,
        .optimize = optimize,
    });

    exe.root_module.addImport("zlua", lua_dep.module("zlua"));
    b.installArtifact(exe);
}

pub fn build(b: *std.Build) void {
    const mode = b.standardOptimizeOption(.{});
    __impl_build(b, "MPBS",       .windows, mode);
    __impl_build(b, "MPBS",       .linux,   mode);
    __impl_build(b, "MPBS.macos", .macos,   mode);
}

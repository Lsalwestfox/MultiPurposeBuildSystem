const std = @import("std");

// don't be afraid when you see empty switch blocks
// it's just abusing switch to discard errors

pub const alloc = std.heap.page_allocator;

pub const logger = struct {
    pub fn log(comptime message: []const u8, args: anytype) void {
        const formatted_message = std.fmt.allocPrint(alloc, "[MPBS] " ++ message ++ "\n", args)
            catch |err| switch (err) { else => { return; } };
        defer alloc.free(formatted_message);
        _ = std.io.getStdOut().write(formatted_message) catch |err| switch (err) {
            else => {
                return;
            }
        };
    }

    pub fn logInfo(comptime message: []const u8, args: anytype) void {
        log("[INFO] " ++ message, args);
    }

    pub fn logError(comptime message: []const u8, args: anytype) void {
        log("[ERROR] " ++ message, args);
    }

    pub fn logWarning(comptime message: []const u8, args: anytype) void {
        log("[WARNING] " ++ message, args);
    }
};

var project_files: ?[]u8 = null;
var exe_path: ?[]u8 = null;

pub fn generateExecutableLocation() !void {
    if (exe_path) |_| {} else {
        exe_path = try std.fs.selfExeDirPathAlloc(alloc);
    }
}

pub fn disposeExecutablePath() void {
    if (exe_path) |path| {
        alloc.free(path);
    }
}

pub fn disposeProjectFilesLocation() void {
    if(project_files) |files| {
        alloc.free(files);
    }
}

pub fn setExecutableLocation(loc: []u8) void {
    exe_path = loc;
}

pub fn setProjectFilesLocation(files: []u8) void {
    project_files = files;
}

pub fn getProjectFilesLocation() []u8 {
    if(project_files) |dir| {
        return dir;
    } else {
        return getExecutableLocation();
    }
}

pub fn getExecutableLocation() []u8 {
    return if (exe_path) |path| {
        return path;
    } else unreachable;
    // this is method always been called after generateExecutableLocation()
    // in this program it's generate on begging and if fails program exists
    // so it's easy to assume that exe_path is always valid at this point
}

pub fn isExistsFile(file: []const u8) bool {
    const dir = std.fs.openFileAbsolute(file, .{});
    defer if (dir) |x| {
        x.close();
    } else |err| {
        switch (err) {
            else => {},
        }
    };
    if (dir) |_| {
        return true;
    } else |err| {
        switch (err) {
            else => {},
        }
        return false;
    }
}

pub fn isExistsDir(file: []const u8) bool {
    const dir = std.fs.openDirAbsolute(file, .{});
    defer if (dir) |x| {
        // x.close()
        // but seems like it's auto close if Dir is const
        _ = x;
    } else |err| {
        switch (err) {
            else => {},
        }
    };
    if (dir) |_| {
        return true;
    } else |err| {
        switch (err) {
            else => {},
        }
        return false;
    }
}

pub fn isExistsLocalFile(file: []const u8) bool {
    const p = resolveAbsolutePathBasedOnProject(file);
    if(p) |output| {
        return isExistsFile(output);
    } else |err| {
        switch(err) {else => {}}
        return false;
    }
}

pub fn isExistsLocalDir(file: []const u8) bool {
    const p = resolveAbsolutePathBasedOnProject(file);
    if(p) |output| {
        return isExistsDir(output);
    } else |err| {
        switch(err) {else => {}}
        return false;
    }
}

pub fn resolveAbsolutePathBasedOnProject(file: []const u8) ![]u8 {
    const dir = try std.fs.openDirAbsolute(getProjectFilesLocation(), .{});
    return dir.realpathAlloc(alloc, file) catch |err| {
        switch(err) {else => {}}
        // it joins path even if good but weird looking so it's only in emergencies
        return try std.fs.path.join(alloc, &[_][]const u8{getProjectFilesLocation(), file});
    };
}

pub fn readFileProject(file: []const u8) ![]u8 {
    const file_path = try resolveAbsolutePathBasedOnProject(file);
    defer alloc.free(file_path);
    return readFile(file_path);
}

pub fn readFileLocally(file: []const u8) ![]u8 {
    const file_path = try std.fs.path.join(alloc, &[_][]const u8{ getExecutableLocation(), file });
    defer alloc.free(file_path);
    return readFile(file_path);
}

pub fn readFile(file_path: []const u8) ![]u8 {
    const file_ = try std.fs.openFileAbsolute(file_path, .{
        .mode = .read_only,
    });
    defer file_.close();
    const end_pos = try file_.getEndPos();
    const buffer = try alloc.alloc(u8, end_pos);
    _ = try file_.readAll(buffer);
    return buffer;
}

pub fn createLocalFile(dir_path: []const u8) bool {
    const p = resolveAbsolutePathBasedOnProject(dir_path);
    if(p) |output| {
        const is_err = std.fs.createFileAbsolute(output, .{});
        if(is_err) |f| {
            f.close();
            return isExistsFile(output);
        } else |err| {
            switch(err) {else => {}}
            return false;
        }
    } else |err| {
        switch(err) {else => {}}
        return false;
    }
}

pub fn createLocalDirectory(dir_path: []const u8) bool {
    const p = resolveAbsolutePathBasedOnProject(dir_path);
    if(p) |output| {
        const is_err = std.fs.makeDirAbsolute(output);
        if(is_err) |_| {
            return isExistsDir(output);
        } else |err| {
            switch(err) {else => {}}
            return false;
        }
    } else |err| {
        switch(err) {else => {}}
        return false;
    }
}

pub fn deleteLocalTree(path: []const u8) !void {
    const dir_path = try resolveAbsolutePathBasedOnProject(path);
    defer alloc.free(dir_path);
    try std.fs.deleteTreeAbsolute(dir_path);
}

pub fn os() [:0]const u8 {
    switch(@import("builtin").target.os.tag) {
        .windows => return "W",
        .linux   => return "L",
        .macos   => return "M",
        else     => return "?",
    }
}
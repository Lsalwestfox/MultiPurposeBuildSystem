const std = @import("std");
const buildin = @import("builtin");

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

pub fn getCwdLocation() ![]u8 {
    const child = std.process.Child.run(.{
        .allocator = alloc,
        .cwd_dir = std.fs.cwd(),
        .argv =
            if(buildin.target.os.tag == .windows) try splitStringBySpace("cmd.exe /C cd")
            else try splitStringBySpace("pwd")
    });

    if(child) |val| {
        if((val.stderr.len > 0) or (val.stdout.len == 0)) {
            return (error { Unexpected }).Unexpected;
        }

        if(buildin.target.os.tag == .windows) {
            return val.stdout[0..val.stdout.len - 2]; // \r\n
        } else {
            return val.stdout[0..val.stdout.len - 1]; // just \n
        }
    } else |err| {
        return err;
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
    defer if(dir) |_| {
        var x = dir catch unreachable;
        x.close();
    } else |err| {
        switch (err) {
            else => {},
        }
    };
    if(dir) |_| {
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
    return try std.fs.path.resolve(alloc, &[_][]const u8{ getProjectFilesLocation(), file });
}

pub fn readFileProject(file: []const u8) ![]u8 {
    const file_path = try resolveAbsolutePathBasedOnProject(file);
    defer alloc.free(file_path);
    return try readFile(file_path);
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

pub fn writeFileProject(file: []const u8, content: []const u8) !void {
    const file_path = try resolveAbsolutePathBasedOnProject(file);
    defer alloc.free(file_path);
    try writeFile(file_path, content);
}

pub fn writeFile(file_path: []const u8, content: []const u8) !void {
    if(!isExistsFile(file_path)) {
        const file_ = try std.fs.createFileAbsolute(file_path, .{});
        defer file_.close();
        try file_.writeAll(content);
    } else {
        const file_ = try std.fs.openFileAbsolute(file_path, .{.mode = .write_only});
        defer file_.close();
        try file_.writeAll(content);
    }
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
            logger.logError("Failed to create directory: {!}", .{err});
            return false;
        }
    } else |err| {
        logger.logError("Error to get absolute path of {s}: {!}", .{dir_path, err});
        return false;
    }
}

pub fn deleteTreeAbsolute(path: []const u8) !void {
    if(buildin.target.os.tag == .windows) {
        const child = std.process.Child.run(.{
            .allocator = alloc,
            .cwd = path,
            .argv = try
                splitStringBySpace("cmd.exe /C del /Q /S * & for /D %i in (*) do rmdir /S /Q \"%i\"")
        });

        if(child) |out| {
            if(out.stderr.len > 0) {
                logger.logError("Failed to delete {s}: {s}", .{path, out.stderr});
                // goto B method
            } else {
                const child2 = std.process.Child.run(.{
                    .argv = &[_][]const u8{"cmd.exe", "/C", "rmdir", "/S", "/Q", path},
                    .allocator = alloc,
                });

                if(child2) |out2| {
                    if(out2.stderr.len > 0) {
                        logger.logError("Failed to delete {s}: {s}", .{path, out.stderr});
                        // goto B method
                    } else {
                        while(isExistsDir(path)) {}
                        return;
                    }
                } else |err| {
                    return err;
                }
            }
        } else |err| {
            return err;
        }
    }

    // B method
    const dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    var iter_dir = dir.iterate();
    while(try iter_dir.next()) |entry| {
        const p = try std.fs.path.resolve(alloc, &[_][]const u8{path, entry.name});
        defer alloc.free(p);

        if(entry.kind == .directory) {
            try deleteTreeAbsolute(p);
            try std.fs.deleteDirAbsolute(p);
        } else {
            try std.fs.deleteFileAbsolute(p);
        }
    }
    try std.fs.deleteDirAbsolute(path);
}

pub fn deleteLocalTree(path: []const u8) !void {
    const dir_path = try resolveAbsolutePathBasedOnProject(path);
    defer alloc.free(dir_path);
    try deleteTreeAbsolute(dir_path);
}

pub fn os() [:0]const u8 {
    switch(@import("builtin").target.os.tag) {
        .windows => return "W",
        .linux   => return "L",
        .macos   => return "M",
        else     => return "?",
    }
}

pub fn splitStringBySpace(input: []const u8) ![]const []const u8 {
    var iterator = std.mem.splitAny(u8, input, " \n");
    var len: usize = 0;
    while(iterator.next()) |_| {
        len += 1;
    }
    iterator.reset();
    var result = try alloc.alloc([]const u8, len);
    var i: usize = 0;
    while(iterator.next()) |val| {
        var x = try alloc.alloc(u8, val.len);
        for(0..val.len) |j| {
            x[j] = val[j];
        }
        result[i] = x;
        i += 1;
    }
    return result;
}
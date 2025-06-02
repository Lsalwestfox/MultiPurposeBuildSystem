const std = @import("std");
const zlua = @import("zlua");
const mpbs = @import("mpbs.zig");
const luaustd = @import("luaustd.zig");
const zlua_args = @import("zlua_args.zig");

const Lua = zlua.Lua;

pub fn main() void {
    defer @import("zlua_dir_iterator.zig").dispose();
    defer zlua_args.dispose();

    var args = std.process.argsWithAllocator(mpbs.alloc) catch |err| {
        mpbs.logger.logError("Failed reading arguments: {!}", .{err});
        return;
    };

    if(@import("builtin").target.os.tag == .windows) {
        mpbs.logger.logInfo("Ignore warnings about build path in W-MPBS build", .{});
    }

    // first argument provided no matter what so you can just do that
    const self_location = args.next() orelse unreachable;

    if(args.next()) |build_dir| {
        const project_files = std.fs.cwd().realpathAlloc(mpbs.alloc, build_dir);

        if(project_files) |directory| {
            mpbs.setProjectFilesLocation(directory);
        } else |err| {
            switch(err) {else => {}}
            mpbs.logger.logWarning("Error getting building directory: {!}", .{err});
            mpbs.logger.logWarning("Getting using plan B", .{});
            const joint = std.fs.path.join(mpbs.alloc, &[_][]const u8{"./", build_dir});
            if(joint) |result| {
                mpbs.setProjectFilesLocation(result);
            } else |err2| {
                mpbs.logger.logError("Error getting building directory: {!}", .{err2});
                return;
            }
        }
    } else {
        mpbs.logger.logInfo("Syntax: {s} <dir> <task> [args...]", .{self_location});
        mpbs.logger.logInfo("Run {s} <dir> to get help", .{self_location});
        return;
    }

    defer mpbs.disposeProjectFilesLocation();
    defer args.deinit();

    mpbs.generateExecutableLocation() catch |err| {
        mpbs.logger.logWarning("Failed to fetch executable location: {!}", .{err});
        mpbs.logger.logWarning("Switching to alternate path...", .{});

        const alternatePath = mpbs.resolveAbsolutePathBasedOnProject(self_location);
        if(alternatePath) |p| {
            mpbs.setExecutableLocation(p);
        } else |err2| {
            mpbs.logger.logError("Failed to fetch executable location: {!}", .{err2});
            return;
        }
    };

    defer mpbs.disposeExecutablePath();

    var lua = Lua.init(mpbs.alloc) catch |err| {
        mpbs.logger.logError("Failed to Initialize luau engine: {!}", .{err});
        return;
    };

    defer lua.deinit();
    luaustd.setup_std(lua);

    const src = mpbs.readFileProject("build.luau") catch |err| {
        mpbs.logger.logError("Failed reading build file: {!}", .{err});
        return;
    };

    defer mpbs.alloc.free(src);

    mpbs.logger.logInfo("{s}-MPBS version v1.1.0", .{mpbs.os()});
    mpbs.logger.logInfo("Build file found", .{});
    mpbs.logger.logInfo("Executable path: {s}", .{mpbs.getExecutableLocation()});
    mpbs.logger.logInfo("Project path: {s}", .{mpbs.getProjectFilesLocation()});

    const task__ = args.next();
    zlua_args.init(&args);

    const bc = zlua.compile(mpbs.alloc, src, zlua.CompileOptions{}) catch |err| {
        mpbs.logger.logError("Failed to compile build file: {!}", .{err});
        return;
    };

    defer mpbs.alloc.free(bc);

    lua.loadBytecode("...", bc) catch |err| {
        mpbs.logger.logError("Failed to load bytecode of build file: {!}", .{err});
        return;
    };

    lua.protectedCall(.{}) catch |err| {
        mpbs.logger.logError("Failed to execute bytecode of build file: {!}", .{err});
        luaustd.receive_error(lua);
    };

    if(task__) |task| if(luaustd.tasks.get(task)) |task_info| {
        _ = lua.getGlobal(task_info.task) catch |err| {
            mpbs.logger.logError("Failed getting global variable: {!}", .{err});
            luaustd.receive_error(lua);
        };
        lua.protectedCall(.{}) catch |err| {
            mpbs.logger.logError("Error running task: {!}", .{err});
            luaustd.receive_error(lua);
        };
    } else {
        mpbs.logger.logInfo("Task {s} not found!", .{task});
    } else {
        mpbs.logger.logInfo("", .{});
        mpbs.logger.logInfo("No task provided to run, available tasks provided below", .{});
        var iterator = luaustd.tasks.iterator();
        while(iterator.next()) |entry| {
            const info = entry.value_ptr;
            if(info.right_pad()) |rp| {
                defer mpbs.alloc.free(rp);
                mpbs.logger.logInfo("\t{s}{s} - {s}", .{info.name, rp, info.description});
            } else |err| {
                mpbs.logger.logError("Failed creating right pad: {!}", .{err});
            }
        }
        mpbs.logger.logInfo("", .{});
        mpbs.logger.logInfo("Arguments for tasks below", .{});
        for(zlua_args.tel.items) |arg_tel| {
            if(arg_tel.right_pad()) |rp| {
                defer mpbs.alloc.free(rp);
                mpbs.logger.logInfo("\t{s}{s} - {s}", .{arg_tel.name, rp, arg_tel.description});
            } else |err| {
                mpbs.logger.logError("Failed creating right pad: {!}", .{err});
            }
        }
    }
}

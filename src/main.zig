const std = @import("std");
const zlua = @import("zlua");
const mpbs = @import("mpbs.zig");
const luaustd = @import("luaustd.zig");
const zlua_args = @import("zlua_args.zig");
const buildin = @import("builtin");

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
    const pwd: []u8 = mpbs.getCwdLocation() catch |err| {
        mpbs.logger.logError("Failed to execute command: {!}", .{err});
        return;
    };

    if(args.next()) |build_dir| {
        const project_files = std.fs.path.resolve(mpbs.alloc, &[_][]const u8{pwd, build_dir});

        if(project_files) |directory| {
            mpbs.setProjectFilesLocation(directory);
        } else |err| {
            mpbs.logger.logError("Error getting building directory: {!}", .{err});
            return;
        }
    } else {
        mpbs.logger.logInfo("Syntax: {s} <dir> <task> [args...]", .{self_location});
        mpbs.logger.logInfo("Run {s} <dir> to get help", .{self_location});
        return;
    }

    defer mpbs.disposeProjectFilesLocation();
    defer args.deinit();

    const __o = std.fs.path.resolve(mpbs.alloc, &[_][]const u8{pwd, self_location});
    if(__o) |loc| {
        mpbs.setExecutableLocation(loc);
    } else |err| {
        mpbs.logger.logWarning("Error getting project directory: {!}", .{err});
        return;
    }

    defer mpbs.disposeExecutablePath();

    mpbs.logger.logInfo("{s}-MPBS version v1.1.1", .{mpbs.os()});
    mpbs.logger.logInfo("Executable path: {s}", .{mpbs.getExecutableLocation()});
    mpbs.logger.logInfo("Project path: {s}", .{mpbs.getProjectFilesLocation()});

    var lua = Lua.init(mpbs.alloc) catch |err| {
        mpbs.logger.logError("Failed to Initialize luau engine: {!}", .{err});
        return;
    };

    defer lua.deinit();
    luaustd.setup_std(lua);

    const src = mpbs.readFileProject("./build.luau") catch |err| {
        mpbs.logger.logError("Failed reading build file: {!}", .{err});
        return;
    };

    defer mpbs.alloc.free(src);

    mpbs.logger.logInfo("Build file found", .{});

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

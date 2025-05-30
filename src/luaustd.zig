const mpbs = @import("mpbs.zig");
const zlua = @import("zlua");
const std = @import("std");

const Lua = zlua.Lua;

pub const Tasks = std.StringHashMap(TaskInfo);
pub var tasks = Tasks.init(mpbs.alloc);
pub var tasks_longest: usize = 0;

pub const TaskInfo = struct {
    description: [:0]const u8,
    task: [:0]const u8,
    name: [:0]const u8,

    pub fn right_pad(self: TaskInfo) ![]u8 {
        var result = try mpbs.alloc.alloc(u8, tasks_longest - self.name.len);
        for(0..result.len) |i| {
            result[i] = ' ';
        }
        return result;
    }
};

fn zluaRegisterTask(lua: *Lua) i32 {
    const name__ = lua.toString(1);
    const desc__ = lua.toString(2);
    const task__ = lua.toString(3);
    if(name__) |name| if(task__) |task| if(desc__) |desc| {
        const o: TaskInfo = .{
            .description = desc,
            .task = task,
            .name = name,
        };

        if(name.len > tasks_longest) {
            tasks_longest = name.len;
        }

        tasks.put(name, o) catch |err| {
            mpbs.logger.logWarning("Failed to register task: {!}", .{err});
        };
    } else |err| {
        mpbs.logger.logWarning("Failed receiving string: {!}", .{err});
    } else |err| {
        mpbs.logger.logWarning("Failed receiving function: {!}", .{err});
        receive_error(lua);
    } else |err| {
        mpbs.logger.logWarning("Failed receiving string: {!}", .{err});
    }
    return 1;
}

fn zluaInfo(lua: *Lua) i32 {
    mpbs.logger.logInfo("{s}", .{ lua.toString(1) catch "[LUAU] [ILLEGAL ARGUMENT]" });
    return 1;
}

fn zluaWarning(lua: *Lua) i32 {
    mpbs.logger.logWarning("{s}", .{ lua.toString(1) catch "[LUAU] [ILLEGAL ARGUMENT]" });
    return 1;
}

fn zluaError(lua: *Lua) i32 {
    mpbs.logger.logError("{s}", .{ lua.toString(1) catch "[LUAU] [ILLEGAL ARGUMENT]" });
    return 1;
}

fn zluaRequire(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |file_path| {
        const result = mpbs.resolveAbsolutePathBasedOnProject(file_path);
        if(result) |path| {
            defer mpbs.alloc.free(path);
            const raw_src = mpbs.readFile(@as([]const u8, path));
            if(raw_src) |src| {
                defer mpbs.alloc.free(src);
                const bc = zlua.compile(mpbs.alloc, src, zlua.CompileOptions{});
                if(bc) |code| {
                    defer mpbs.alloc.free(code);
                    const r = lua.loadBytecode("...", code);
                    if(r) |_| {
                        const r2 = lua.protectedCall(.{ .results = 1 });
                        if(r2) |_| {} else |err| {
                            mpbs.logger.logWarning("[LUAU] Failed to execute bytecode of build file: {!}", .{err});
                            receive_error(lua);
                            lua.pushNil();
                        }
                    } else |err| {
                        mpbs.logger.logWarning("[LUAU] Failed to load bytecode of build file: {!}", .{err});
                        lua.pushNil();
                    }
                } else |err| {
                    mpbs.logger.logWarning("[LUAU] Failed to compile build file: {!}", .{err});
                    lua.pushNil();
                }
            } else |err| {
                mpbs.logger.logWarning("[LUAU] Failed to load file {s}: {!}", .{file_path, err});
                lua.pushNil();
            }
        } else |err| {
            mpbs.logger.logWarning("[LUAU] Failed get absolute path: {!}", .{err});
            lua.pushNil();
        }
    } else |err| {
        mpbs.logger.logWarning("[LUAU] Failed to get first argument for require: {!}", .{err});
        lua.pushNil();
    }
    return 1;
}

fn zluaResolveAbstract(lua: *Lua) i32 {
    const relative = lua.toString(1);
    if(relative) |x| {
        const absolute = mpbs.resolveAbsolutePathBasedOnProject(x);
        if(absolute) |push| {
            defer mpbs.alloc.free(push);
            _ = lua.pushString(push);
        } else |err| {
            mpbs.logger.logWarning("Failed to resolve abstract path {s}: {!}", .{x, err});
            lua.pushNil();
        }
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushNil();
    }
    return 1;
}

fn splitStringBySpace(input: []const u8) ![]const []const u8 {
    var iterator = std.mem.splitAny(u8, input, " \n");
    var len: usize = 0;
    while(iterator.next()) |_| {
        len += 1;
    }
    iterator.reset();
    var result = try mpbs.alloc.alloc([]const u8, len);
    var i: usize = 0;
    while(iterator.next()) |val| {
        var x = try mpbs.alloc.alloc(u8, val.len);
        for(0..val.len) |j| {
            x[j] = val[j];
        }
        result[i] = x;
        i += 1;
    }
    return result;
}

fn zluaExecute(lua: *Lua) i32 {
    const command = lua.toString(1);
    if(command) |cmd| {
        const argv = splitStringBySpace(cmd);

        if(argv) |value| {
            mpbs.logger.logInfo("{s}", .{cmd});

            const child = std.process.Child.run(.{
                .allocator = mpbs.alloc,
                .cwd = mpbs.getProjectFilesLocation(),
                .argv = value,
            });

            if(child) |val| {
                if(val.stderr.len > 0) mpbs.logger.logError("\n{s}", .{val.stderr});
                if(val.stdout.len > 0) mpbs.logger.logInfo("\n{s}", .{val.stdout});
            } else |err| {
                mpbs.logger.logWarning("Failed to execute: {!}", .{err});
            }
        } else |err| {
            mpbs.logger.logWarning("Failed to split string value: {!}", .{err});
        }
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
    }
    return 1;
}

fn zluaReadLocalFile(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |f| {
        const content = mpbs.readFileProject(f);
        if(content) |cnt| {
            _ = lua.pushString(cnt);
        } else |err| {
            mpbs.logger.logWarning("Failed to read {s}: {!}", .{f, err});
            lua.pushNil();
        }
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushNil();
    }
    return 1;
}

fn zluaIsExistsLocalFile(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |path| {
        lua.pushInteger(if(mpbs.isExistsLocalFile(path)) 1 else 0);
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushInteger(0);
    }
    return 1;
}

fn zluaIsExistsLocalDir(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |path| {
        lua.pushInteger(if(mpbs.isExistsLocalDir(path)) 1 else 0);
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushInteger(0);
    }
    return 1;
}

fn zluaCreateLocalFile(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |path| {
        lua.pushInteger(if(mpbs.createLocalFile(path)) 1 else 0);
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushInteger(0);
    }
    return 1;
}

fn zluaCreateLocalDir(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |path| {
        lua.pushInteger(if(mpbs.createLocalDirectory(path)) 1 else 0);
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushInteger(0);
    }
    return 1;
}

fn zluaDeleteLocalFileOrDir(lua: *Lua) i32 {
    const file = lua.toString(1);
    if(file) |path| {
        const output = mpbs.deleteLocalTree(path);
        if(output) |_| {
            lua.pushInteger(1);
        } else |err| {
            switch(err) {else => {}}
            lua.pushInteger(0);
        }
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
        lua.pushInteger(0);
    }
    return 1;
}

pub fn setup_std(lua: *Lua) void {
    lua.pushFunction(zlua.wrap(zluaRequire));
    lua.setGlobal("require");

    lua.pushFunction(zlua.wrap(zluaInfo));
    lua.setGlobal("__impl_info");
    lua.pushFunction(zlua.wrap(zluaError));
    lua.setGlobal("__impl_error");
    lua.pushFunction(zlua.wrap(zluaWarning));
    lua.setGlobal("__impl_warning");
    lua.pushFunction(zlua.wrap(zluaResolveAbstract));
    lua.setGlobal("__impl_resolve_abstract");
    lua.pushFunction(zlua.wrap(zluaRegisterTask));
    lua.setGlobal("__impl_register_task");
    lua.pushFunction(zlua.wrap(zluaExecute));
    lua.setGlobal("__impl_execute");
    lua.pushFunction(zlua.wrap(zluaReadLocalFile));
    lua.setGlobal("__impl_read_local_file");
    lua.pushFunction(zlua.wrap(zluaIsExistsLocalFile));
    lua.setGlobal("__impl_is_exists_local_file");
    lua.pushFunction(zlua.wrap(zluaIsExistsLocalDir));
    lua.setGlobal("__impl_is_exists_local_dir");
    lua.pushFunction(zlua.wrap(zluaCreateLocalFile));
    lua.setGlobal("__impl_create_local_file");
    lua.pushFunction(zlua.wrap(zluaCreateLocalDir));
    lua.setGlobal("__impl_create_local_dir");
    lua.pushFunction(zlua.wrap(zluaDeleteLocalFileOrDir));
    lua.setGlobal("__impl_delete_local_file_or_dir");

    _ = lua.pushString(mpbs.getExecutableLocation());
    lua.setGlobal("__IMPL_EXECUTABLE_LOCATION__");
    _ = lua.pushString(mpbs.getProjectFilesLocation());
    lua.setGlobal("__IMPL_PROJECT_DIRECTORY__");
    _ = lua.pushString(mpbs.os());
    lua.setGlobal("__IMPL_OS__");
}

pub fn receive_error(lua: *Lua) void {
    const lua_err = lua.toString(-1);
    if(lua_err) |err_msg| {
        mpbs.logger.logWarning("[LUAU] Received runtime lua error info: {s}", .{err_msg});
    } else |err2| switch(err2) {
        else => {}
    }
}
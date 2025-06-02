const mpbs = @import("mpbs.zig");
const zlua = @import("zlua");
const std = @import("std");
const fs = std.fs;

const Lua = zlua.Lua;
const Dir = fs.Dir;

const DirStack = std.ArrayList(*DirOnStack);
var stack: DirStack = DirStack.init(mpbs.alloc);
var recursive = false;

// i thought iterators of directories were connected
// oops lol

const DirOnStack = struct {
    dir: Dir,
    name: ?[]const u8,
    iterator: Dir.Iterator,
    index: usize,
};

fn zluaNextName(lua: *Lua) i32 {
    if(stack.getLastOrNull()) |current| {
        current.iterator.reset();
        for(0..current.index) |_| {
            _ = current.iterator.next() catch |err| {
                switch(err) { else => {} }
            };
        }
        if(current.iterator.next()) |entry__| if(entry__) |entry| {
            current.index += 1;

            var output = entry.name;
            for(stack.items) |x| {
                if(x.name) |name| {
                    if(mpbs.alloc.alloc(u8, name.len + output.len + 1)) |value| {
                        std.mem.copyBackwards(u8, value, name);
                        value[name.len] = '/';
                        std.mem.copyBackwards(u8, value[name.len + 1..], output);
                        output = value;
                    } else |err| {
                        mpbs.logger.logWarning("Allocation failure: {!}", .{err});
                    }
                }
            }

            _ = lua.pushString(output);

            if((entry.kind == .directory) and recursive) {
                if(current.dir.openDir(entry.name, .{.iterate = true, .no_follow = true})) |d| {
                    if(mpbs.alloc.create(DirOnStack)) |dir_on_stack| {
                        dir_on_stack.dir = d;
                        dir_on_stack.name = entry.name;
                        dir_on_stack.iterator = d.iterate();
                        dir_on_stack.index = 0;
                        stack.append(dir_on_stack) catch |err| {
                            mpbs.logger.logWarning("Error adding directory: {!}", .{err});
                        };
                    } else |err| {
                        mpbs.logger.logWarning("Allocation failure: {!}", .{err});
                    }
                } else |err| {
                    mpbs.logger.logWarning("Error reading directory: {!}", .{err});
                }
            }
        } else {
            // this means that thing ended iterating
            _ = stack.pop();
            return zluaNextName(lua);
        } else |err| {
            // this means that thing ended iterating
            _ = stack.pop();
            mpbs.logger.logWarning("Error getting entry: {!}", .{err});
            lua.pushNil();
        }
    } else {
        lua.pushNil();
    }
    return 1;
}

fn zluaSet(lua: *Lua) i32 {
    if(lua.toString(1)) |dir| if(lua.toNumber(2)) |r| {
        if(mpbs.resolveAbsolutePathBasedOnProject(dir)) |a| {
            if(fs.openDirAbsolute(a, .{.iterate = true, .no_follow = true})) |d| {
                if(mpbs.alloc.create(DirOnStack)) |dir_on_stack| {
                    dir_on_stack.iterator = d.iterate();
                    dir_on_stack.dir = d;
                    dir_on_stack.name = null;
                    dir_on_stack.index = 0;
                    if(stack.append(dir_on_stack)) |_| {
                        recursive = (r == 1);
                    } else |err| {
                        mpbs.logger.logWarning("Failed adding directory: {!}", .{err});
                    }
                } else |err| {
                    mpbs.logger.logWarning("Allocation failure: {!}", .{err});
                }
            } else |err| {
                mpbs.logger.logWarning("Failed reading directory: {!}", .{err});
            }
        } else |err| {
            mpbs.logger.logWarning("Failed receiving absolute path: {!}", .{err});
        }
    } else |err| {
        mpbs.logger.logWarning("Failed to receive integer value: {!}", .{err});
    } else |err| {
        mpbs.logger.logWarning("Failed to receive string value: {!}", .{err});
    }
    return 1;
}

pub fn expose(lua: *Lua) void {
    lua.pushFunction(zlua.wrap(zluaNextName));
    lua.setGlobal("__impl_next_dir_entry");
    lua.pushFunction(zlua.wrap(zluaSet));
    lua.setGlobal("__impl_set_dir_entries");
}

pub fn dispose() void {
    stack.clearAndFree();
    stack.deinit();
}
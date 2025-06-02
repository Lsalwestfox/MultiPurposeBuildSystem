const std = @import("std");
const zlua = @import("zlua");
const mpbs = @import("mpbs.zig");

const Lua = zlua.Lua;
pub const ArgsArray = std.ArrayList([]const u8);
pub const ArgsTelemetry = std.ArrayList(ArgTelemetry);

pub const ArgTelemetry = struct {
    name: [:0]const u8,
    description: [:0]const u8,

    pub fn right_pad(self: ArgTelemetry) ![]u8 {
        var result = try mpbs.alloc.alloc(u8, longest - self.name.len);
        for(0..result.len) |i| {
            result[i] = ' ';
        }
        return result;
    }
};

var arr = ArgsArray.init(mpbs.alloc);
pub var tel = ArgsTelemetry.init(mpbs.alloc);
var longest: usize = 0;

fn zluaAddArgTelemetry(lua: *Lua) i32 {
    if(lua.toString(1)) |name|
    if(lua.toString(2)) |description|
    {
        tel.append(.{
            .name = name,
            .description = description
        }) catch |err| switch(err) { else => {} };
        if(name.len > longest) longest = name.len;
    }
    else |err| switch(err) { else => {} } else |err| switch(err) { else => {} }
    return 1;
}

fn zluaNumOfArgs(lua: *Lua) i32 {
    lua.pushInteger(@intCast(arr.items.len));
    return 1;
}

fn zluaArgsAt(lua: *Lua) i32 {
    if(lua.toInteger(1)) |i| {
        _ = lua.pushString(arr.items[@intCast(i)]);
    } else |err| {
        switch(err) { else => {} }
        lua.pushNil();
    }
    return 1;
}

fn zluaContainsArg(lua: *Lua) i32 {
    if(lua.toString(1)) |str| {
        for(0..arr.items.len) |i| {
            const item = arr.items[i];
            if(std.mem.eql(u8, item, str)) {
                lua.pushInteger(@intCast(i));
                return 1;
            }
        }
        lua.pushInteger(-1);
    } else |err| {
        switch(err) { else => {} }
        lua.pushInteger(-1);
    }
    return 1;
}

pub fn init(args: *std.process.ArgIterator) void {
    while(args.next()) |value| {
        arr.append(value) catch |err| {
            switch(err) { else => {} }
        };
    }
}

pub fn dispose() void {
    arr.clearAndFree();
    arr.deinit();
    tel.clearAndFree();
    tel.deinit();
}

pub fn expose(lua: *Lua) void {
    lua.pushFunction(zlua.wrap(zluaArgsAt));
    lua.setGlobal("__impl_arg_at");
    lua.pushFunction(zlua.wrap(zluaContainsArg));
    lua.setGlobal("__impl_arg_contains");
    lua.pushFunction(zlua.wrap(zluaNumOfArgs));
    lua.setGlobal("__impl_arg_num");
    lua.pushFunction(zlua.wrap(zluaAddArgTelemetry));
    lua.setGlobal("__impl_arg_telemetry");
}
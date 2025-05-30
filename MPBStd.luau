--- The version of MPBS standard library
type StdVersion = {
    full: string,
    major: number,
    medium: number,
    minor: number
}

--- The bridge between MPBS and luau code, containing methods to work with
--- the second reason is because language server don't know about MPBS so implemented by MPBS
--- fields and methods gonna be not found and everything is red, this is to prevent that
type StdInterface = {
    version: StdVersion,
    os: "W" | "L" | "M" | "?",
    is_unix: number,

    executablePath: string,
    projectPath: string,

    info: (message: string) -> nil,
    warn: (message: string) -> nil,
    err: (message: string) -> nil,

    --- Convert location relative to project directory (./ or ../) to the absolute path
    resolveAbstract: (path: string) -> string,

    --- Registers task to the MPBS so user can execute it
    registerTask: (name: string, description: string | nil, task: string) -> nil,

    --- Execute operation-system specific command
    execute: (command: string) -> nil,

    --- Reads local file in project path
    readLocalFile: (file: string) -> string,

    --- Returns 1 if found, 0 if not
    isExistsLocalFile: (file: string) -> number,

    --- Returns 1 if found, 0 if not
    isExistsLocalDir: (file: string) -> number,

    --- Returns 1 if successfully create and 0 if not
    createLocalFile: (file: string) -> number,

    --- Returns 1 if successfully create and 0 if not
    createLocalDir: (file: string) -> number,

    --- Recursive, like rm -rf, returns 1 if successfully removes and 0 if not
    deleteLocalDirOrFile: (file: string) -> number
}

local std: StdInterface = {
    executablePath = __IMPL_EXECUTABLE_LOCATION__,
    projectPath = __IMPL_PROJECT_DIRECTORY__,
    os = __IMPL_OS__,
    is_unix = ((__IMPL_OS__ == "W") and 1000 or 1001) - 1000,

    version = {
        full = "v1.0.0",
        major = 1,
        medium = 0,
        minor = 0
    },

    info = function(message: string)
        __impl_info(message)
    end,

    warn = function(message: string)
        __impl_warning(message)
    end,

    err = function(message: string)
        __impl_error(message)
    end,

    resolveAbstract = function(path: string): string
        return __impl_resolve_abstract(path)
    end,

    registerTask = function(name: string, description: string | nil, task: string)
        if(description == nil) then description = "No description" end
        __impl_register_task(name, description, task)
    end,

    execute = function(command: string)
        __impl_execute(command)
    end,

    readLocalFile = function(file: string): string
        return __impl_read_local_file(file)
    end,

    isExistsLocalFile = function(file: string): number
        return __impl_is_exists_local_file(file);
    end,

    isExistsLocalDir = function(dir: string): number
        return __impl_is_exists_local_dir(dir);
    end,

    createLocalFile = function(file: string): number
        return __impl_create_local_file(file);
    end,

    createLocalDir = function(dir: string): number
        return __impl_create_local_dir(dir);
    end,

    deleteLocalDirOrFile = function(dir: string): number
        return __impl_delete_local_file_or_dir(dir);
    end,
}

std.info("MPBS standard library " .. std.version.full)
return std
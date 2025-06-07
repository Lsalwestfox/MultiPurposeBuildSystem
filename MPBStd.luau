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

    --- Writes local file in project path
    writeLocalFile: (file: string, content: string?) -> nil,

    --- Adds content to the end of the file, can be used to create file too
    appendLocalFile: (file: string, content: string?) -> nil,

    --- Returns 1 if found, 0 if not
    isExistsLocalFile: (file: string) -> number,

    --- Returns 1 if found, 0 if not
    isExistsLocalDir: (file: string) -> number,

    --- Returns 1 if successfully create and 0 if not
    createLocalFile: (file: string) -> number,

    --- Returns 1 if successfully create and 0 if not
    createLocalDir: (file: string) -> number,

    --- Recursive, like rm -rf, returns 1 if successfully removes and 0 if not
    deleteLocalDirOrFile: (file: string) -> number,

    --- See CXXInstance
    createCompilerInstance: () -> CXXInstance,

    --- Tries to create directory if not exists, returns 1 if exists, 0 if not
    createLocalDirIfNotExists: (dir: string) -> number,

    --- Tries to delete and then create directory, returns 1 if successfully, 0 if not
    --- If returns 0 then directory can existing but not guaranteed that it will be empty
    recreateLocalDir: (dir: string) -> number,

    --- Creates ./mpbs-cache and recreates ./mpbs-cache/bin and ./mpbs-cache/obj
    --- Created for fast creation of correct directories if you gonna stick to standard
    setupCXXStdEnv: () -> nil,
    --- Creates ./mpbs-cache
    --- Created for fast creation of correct directories if you gonna stick to standard
    setupCacheDir: () -> nil,

    --- Downloads file from url, shocking
    --- Curl must be installed
    downloadFrom: (url: string, dest: string) -> nil,

    --- Gets file names of all directories
    readAllEntries: (dir: string) -> {string},

    --- Gets file names of all directories recursively
    realAllEntriesRecursive: (dir: string) -> {string},

    argNum: () -> number,
    argAt: (index: number) -> string,
    argContains: (arg: string) -> number,
    addArgTelemetry: (name: string, description: string) -> nil,
}

--- A std creation of C/CPP compilation step
type CXXInstance = {
    --- Flags that will be present for both release and debug modes
    flags: string | nil,
    --- Flags that will be present only in debug mode
    debugFlags: string | nil,
    --- Flags that will be present only in release mode
    releaseFlags: string | nil,
    --- The program to compile code
    compiler: string,
    --- The linker being used to accept all .o files
    linker: string?,
    --- CXX files used to compile that
    sources: {string},
    --- Include directories for .h files
    includes: {string},
    --- Libraries directories for .lib / .a files
    libraries: {string},
    --- Do not confuse with libraries field, this field used for -l flags, you know if know
    libraries_: {string},

    --- Output of .o files, including file name
    obj_output: string,
    --- Output folder of program
    bin_output: string,

    --- Creates a command that you can run for getting .o / linking
    compileFlags: (compiler: string, mn: string?, additionalFlags: string?) -> string,
    --- Compiles using compiler
    compileObjectFiles: (additionalFlags: string?) -> nil,

    --- Calls compile with release flags, see compile
    compileRelease: (name: string, additionalFlags: string) -> nil,
    --- Calls compile with debug flags, see compile
    compileDebug: (name: string, additionalFlags: string) -> nil,
    --- Compiles a struct with provided additional flags
    --- Supported compilers: g++, gcc, clang++, clang, zig cc, zig c++
    --- Flags used: -O0-3, -L, -I, -l, -o, -c
    compile: (name: string, additionalFlags: string) -> nil,

    --- Helper function, for clang++ use clangCPPCompiler function
    clangCCompiler: () -> nil,
    --- Helper function, for clang use clangCCompiler function
    clangCPPCompiler: () -> nil,
    --- Helper function, for g++ use gppCompiler function
    gccCompiler: () -> nil,
    --- Helper function, for gcc use gccCompiler function
    gppCompiler: () -> nil,
    --- Helper function, for zig c++ use zigCPPCompiler function
    zigCompiler: () -> nil,
    --- Helper function, for zig cc use zigCompiler function
    zigCPPCompiler: () -> nil,

    --- Helper function, sets linker to be compiler, so executable and not static library
    defaultLinker: () -> nil,
    --- Helper function, ar - unix, lib.exe - windows
    osSpecificLinker: () -> nil,
    --- Helper function
    arRcsLinker: () -> nil,
    --- Helper function
    libExeLinker: () -> nil,
    --- Helper function, uses zig build-in ar
    zigArRcsLinker: () -> nil,
    --- Helper function, uses zig build-in lib.exe
    zigLibExeLinker: () -> nil,

    --- Helper function
    addSourceFile: (source: string) -> nil,
    --- Helper function
    addIncludeFolder: (folder: string) -> nil,
    --- Helper function
    addLibraryFolder: (folder: string) -> nil,
    --- Helper function
    addLibrary: (flag: string) -> nil,
    --- Helper function, must not end with "/" or "\\"
    addSourceFilesFromDirectory: (source: string) -> nil,
}

local std = {
    executablePath = __IMPL_EXECUTABLE_LOCATION__,
    projectPath = __IMPL_PROJECT_DIRECTORY__,
    os = __IMPL_OS__,
    is_unix = ((__IMPL_OS__ == "W") and 1000 or 1001) - 1000,

    version = {
        full = "v1.1.1",
        major = 1,
        medium = 1,
        minor = 1
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

    writeLocalFile = function(file: string, content: string?)
        if(content == nil) then
            __impl_write_local_file(file, "")
        else
            __impl_write_local_file(file, content)
        end
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

    readAllEntries = function(dir: string): {string}
        local output: {string} = {}
        __impl_set_dir_entries(dir, 0)
        local tmp = __impl_next_dir_entry()
        while(tmp ~= nil) do
            table.insert(output, tmp)
            tmp = __impl_next_dir_entry()
        end
        return output;
    end,

    realAllEntriesRecursive = function(dir: string): {string}
        local output: {string} = {}
        __impl_set_dir_entries(dir, 1)
        local tmp = __impl_next_dir_entry()
        while(tmp ~= nil) do
            table.insert(output, tmp)
            tmp = __impl_next_dir_entry()
        end
        return output;
    end,

    argNum = function(): number
        return __impl_arg_num()
    end,

    argAt = function(index: number): string
        return __impl_arg_at(index)
    end,

    argContains = function(arg: string): number
        return __impl_arg_contains(arg)
    end,

    addArgTelemetry = function(name: string, description: string)
        __impl_arg_telemetry(name, description)
    end
}

function std.appendLocalFile(file: string, content: string?)
    if(std.isExistsLocalFile(file) == 0) then
        std.writeLocalFile(file, content)
        return
    end

    if(content ~= nil) then
        std.writeLocalFile(file, std.readLocalFile(file) .. content)
    end
end

function std.createCompilerInstance(): CXXInstance
    local instance = {
        flags = "-static",
        debugFlags = "-O0 -g",
        releaseFlags = "-O3",
        compiler = "unknown",
        sources = {},
        includes = {},
        libraries = {},
        libraries_ = {},
        obj_output = "./mpbs-cache/obj/obj",
        bin_output = "./mpbs-cache/bin/",
        linker = nil,
    };

    function instance.compileFlags(compiler: string, mn: string?, additionalFlags: string?): string
        local flags: string = compiler;

        if(instance.flags ~= nil) then
            flags = flags .. " " .. instance.flags
        end

        if(additionalFlags ~= nil) then
            flags = flags .. " " .. additionalFlags
        end

        for i = 1, #instance.includes do
            flags = flags .. " -I" .. instance.includes[i]
        end

        for i = 1, #instance.libraries do
            flags = flags .. " -L" .. instance.libraries[i]
        end

        if(mn ~= nil) then
            flags = flags .. " " .. mn
        end

        for i = 1, #instance.libraries_ do
            flags = flags .. " -l" .. instance.libraries_[i]
        end

        return flags;
    end

    function instance.compileObjectFiles(additionalFlags: string?)
        for i = 1, #instance.sources do
            std.execute(instance.compileFlags(
                instance.compiler,
                "-c " .. instance.sources[i] .. " -o " .. instance.obj_output .. i .. ".o",
                additionalFlags
            ))
        end
    end

    function instance.compileRelease(name: string, additionalFlags: string?)
        if(additionalFlags == nil) then
            instance.compile(name, instance.releaseFlags)
        elseif(instance.releaseFlags == nil) then
            instance.compile(name, additionalFlags)
        else
            instance.compile(name, instance.releaseFlags .. " " .. additionalFlags)
        end
    end

    function instance.compileDebug(name: string, additionalFlags: string?)
        if(additionalFlags == nil) then
            instance.compile(name, instance.debugFlags)
        elseif(instance.debugFlags == nil) then
            instance.compile(name, additionalFlags)
        else
            instance.compile(name, instance.debugFlags .. " " .. additionalFlags)
        end
    end

    function instance.compile(name: string, additionalFlags: string?)
        instance.compileObjectFiles(additionalFlags);

        local s = ""
        for i = 1, #instance.sources do
            s = s .. " " .. instance.obj_output .. i .. ".o"
        end

        local flags = ""
        if(instance.linker ~= nil) then
            flags = instance.linker .. instance.bin_output .. name .. s
        else
            flags = instance.compileFlags(instance.compiler, "-o " .. instance.bin_output .. name .. s, additionalFlags)
        end

        std.execute(flags)
    end

    function instance.addSourceFilesFromDirectory(source: string)
        local dirs = std.realAllEntriesRecursive(source .. "/")
        for i = 1, #dirs do
            instance.addSourceFile(source .. "/" .. dirs[i])
        end
    end

    function instance.clangCCompiler()   instance.compiler = "clang"   end
    function instance.clangCPPCompiler() instance.compiler = "clang++" end
    function instance.gccCompiler()      instance.compiler = "gcc"     end
    function instance.gppCompiler()      instance.compiler = "g++"     end
    function instance.zigCompiler()      instance.compiler = "zig cc"  end
    function instance.zigCPPCompiler()   instance.compiler = "zig c++" end

    function instance.defaultLinker()    instance.linker = nil               end
    function instance.arRcsLinker()      instance.linker = "ar rcs "         end
    function instance.libExeLinker()     instance.linker = "lib /OUT:"       end
    function instance.zigArRcsLinker()   instance.linker = "zig ar rcs "     end
    function instance.zigLibExeLinker()  instance.linker = "zig lib /OUT:"   end

    function instance.osSpecificLinker()
        if(std.is_unix == 1) then
            instance.arRcsLinker()
        else
            instance.libExeLinker()
        end
    end

    function instance.addSourceFile(source: string)     table.insert(instance.sources, source)   end
    function instance.addIncludeFolder(folder: string)  table.insert(instance.includes, folder)  end
    function instance.addLibraryFolder (folder: string) table.insert(instance.libraries, folder) end
    function instance.addLibrary(flag: string)          table.insert(instance.libraries_, flag)  end

    return instance;
end

function std.createLocalDirIfNotExists(dir: string): number
    if((std.isExistsLocalDir(dir) == 0) and (std.createLocalDir(dir) == 0)) then
        return 0
    else
        return 1
    end
end

function std.recreateLocalDir(dir: string): number
    if(std.isExistsLocalDir(dir) == 1) then
        if(std.deleteLocalDirOrFile(dir) == 0) then
            return 0
        end
    end

    if(std.createLocalDir(dir) == 0) then
        return 0
    end

    return 1
end

function std.setupCacheDir()
    if(std.createLocalDirIfNotExists("./mpbs-cache") == 0) then
        std.err("Failed to create cache directory")
        return
    end
end

function std.setupCXXStdEnv()
    std.setupCacheDir()

    if(std.recreateLocalDir("./mpbs-cache/bin") == 0) then
        std.err("Failed to recreate bin directory")
        return
    end

    if(std.recreateLocalDir("./mpbs-cache/obj") == 0) then
        std.err("Failed to recreate objects directory")
        return
    end
end

function std.downloadFrom(url: string, dest: string)
    std.execute("curl -o " .. dest .. " " .. url)
end

function __type_implementation_check(_std: StdInterface)
    _std.info("MPBS standard library " .. _std.version.full)
end

__type_implementation_check(std);
return std
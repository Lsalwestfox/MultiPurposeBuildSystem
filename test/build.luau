-- The std .luau file mostly in the same place where MPBS
-- in this case it's not, as you see it uses project path
-- project path is directory where this file is
-- if you want do according to standards, in project should be
-- mpbs folder which all 3 executables and std.luau and other files
-- require build script to work meanwhile mpbs-cache folder for outputs
-- or temporary/.gitignore data like fetches from the internet
-- btw windows support "/" as "\\" so this is good
-- forgot to say, filepaths leading to this project and executable
-- recommended to be not containing spaces
local std = require("../MPBStd.luau")

-- also exists std.warn and std.err for logs
-- std.os => L if linux, W if windows and M if macos
-- std.info("OS: " .. std.os .. ", is unix: " .. std.is_unix)

-- std provides arguments, argContains returns index to the argument and -1 if not found
if(std.argContains("--show-args") ~= -1) then
    std.info("Args amount" .. std.argNum())
    for i = 0, std.argNum() do
        std.info(std.argAt(i));
    end
end

-- Luau Language Server (JohnnyMorganz's one) VSCode extension
-- don't say function unused if it begins with "_", but because function
-- used by MPBS if function begins with "_" it's a task now a standard
-- also if extension installed you can lookup in std comments fast

function _setup()
    -- note that directory will not be create if subfolder are missing
    -- this is why we create ./mpbs-cache directory first

    -- directory being created if not exists only
    -- you can always look in std file to see what it does
    if(std.createLocalDirIfNotExists("./mpbs-cache") == 0) then
        std.err("Failed to create cache directory")
        return
    end

    -- directory being deleted if exists and created again
    -- this way directory always empty
    if(std.recreateLocalDir("./mpbs-cache/bin") == 0) then
        std.err("Failed to recreate bin directory")
        return
    end

    -- directory for .o files
    if(std.recreateLocalDir("./mpbs-cache/obj") == 0) then
        std.err("Failed to recreate objects directory")
        return
    end
end

function _test()
    std.setupCXXStdEnv()

    -- std provides interface for C and C++ code compilation
    -- but you can don't use it if you want it's entirely in luau
    -- running shell commands (just like CMake normal edition)
    -- if only one task uses this instance it's recommended make it local
    -- to the task it uses, yes you can have multiple of those
    local instance = std.createCompilerInstance()
    instance.gppCompiler()
    instance.addSourceFilesFromDirectory("./src")
    instance.addIncludeFolder("include")
    instance.addLibraryFolder("mpbs-cache/lib")
    instance.addLibrary("memrand_" .. std.os)

    if(std.is_unix == 1) then
        instance.compileDebug("program")
        std.execute(instance.bin_output .. "program")
    else
        instance.compileDebug("program.exe")
        std.execute(instance.bin_output .. "program.exe")
    end
end

-- an example how create a library, here i use zig c++ compiler
-- and build-in ar/lib.exe because it's just easier to build cross-platform
function _build()
    -- this STD command do the same thing as _setup, line by line
    -- i create _setup to as example of directory manipulation
    std.setupCXXStdEnv()

    if(std.recreateLocalDir("./mpbs-cache/lib") == 0) then
        std.info("Failed to recreate cache lib directory")
        return
    end

    local instance = std.createCompilerInstance()
    instance.bin_output = "./mpbs-cache/lib/"
    instance.addSourceFile("./lib.cpp")
    instance.addIncludeFolder("include")

    instance.zigCPPCompiler()
    instance.zigArRcsLinker()
    instance.compileRelease("libmemrand_L.a", "-target x86_64-linux-musl")
    instance.zigLibExeLinker()
    instance.compileRelease("libmemrand_W.a", "-target x86_64-windows-gnu")
end

-- this function demonstrates how do I/O with files
function _do_something_in_cache()
    std.setupCacheDir()

    std.writeLocalFile("./mpbs-cache/empty_file.txt")
    std.writeLocalFile("./mpbs-cache/file.txt", "Deez nuts")

    -- appendLocalFile appends to the end of the file
    std.appendLocalFile("./mpbs-cache/i_accumulate.txt", "Ligma balls ")

    if(std.isExistsLocalFile("./mpbs-cache/non_exist.txt") == 0) then
        std.info("Sorry, file not found")
    end

    std.downloadFrom(
        "https://raw.githubusercontent.com/Lsalwestfox/MultiPurposeBuildSystem/refs/tags/v1.0.0/.gitignore",
        "./mpbs-cache/git_ignore_of_the_MPBS_but_old.lol.txt"
    )

    std.appendLocalFile("./mpbs-cache/git_ignore_of_the_MPBS_but_old.lol.txt", "\n\nLook at that shit! LMAO!!!")
end

-- now register defined function above, because how lua C library works
-- the third argument is function name that defined in global space
-- in current case is the function above that starts with "_"
-- will throw seg fault is you try define task in another place other that that
std.registerTask("setup_env", "Calls std.setupCXXStdEnv",                        "_setup")
std.registerTask("build",     "Builds a library in release mode",                "_build")
std.registerTask("test",      "Tests a project in debug mode",                   "_test")
std.registerTask("ligma",     "Writes something and fetches file from internet", "_do_something_in_cache")

function _noop() end
std.registerTask("noop", "Does nothing, used for providing arguments only / debugging", "_noop")

-- don't forget show to the user what args available
std.addArgTelemetry("--show-args",     "Shows args information like count and values")
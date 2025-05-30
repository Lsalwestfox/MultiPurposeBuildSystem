-- The std .luau file mostly in the same place where MPBS
-- in this case it's not, as you see it uses project path
-- project path is directory where this file is
-- if you want do according to standards, in project should be
-- mpbs folder which all 3 executables and std.luau and other files
-- require build script to work meanwhile mpbs-cache folder for outputs
-- or temporary/.gitignore data like fetches from the internet
local std = require("../MPBStd.luau")

-- flags that wil be provided to gcc compiler
local gcc_flags = "-O3 -Iinclude -static -static-libgcc -static-libstdc++"
-- specifies output path of program, as standard it's mpbs-cache/bin/
-- in this build file it must end with "/"
-- btw windows support "/" as "\\" so this is good
-- note that in this file, program deletes output_path and create folder again
local output_path = "./mpbs-cache/bin/"
-- output executable location
local output_executable = output_path .. "program"

if(std.os == "W") then
    output_executable = output_executable .. ".exe"
end

-- also exists std.warn and std.err for logs
-- std.os => L if linux, W if windows and M if macos
-- std.info("OS: " .. std.os .. ", is unix: " .. std.is_unix)

-- example of reading file
-- td.info("\n" .. std.readLocalFile("./src/main.cpp"))

-- temporary values for build_file function
local final_command: string = "g++ -o " .. output_executable;
local counter: number = 0;

-- std.execute runs shell commands, self explanatory
--- compiling file using g++ and adding to files need to link between
function build_file(file: string)
    std.execute("g++ " .. gcc_flags .. " -o " .. output_path .. "__" .. counter .. ".o -c " .. file)
    final_command = final_command .. " " .. output_path .. "__" .. counter .. ".o"
    counter = counter + 1
end

-- Luau Language Server (JohnnyMorganz's one) VSCode extension
-- don't say function unused if it begins with "_", but because function
-- used by MPBS if function begins with "_" it's a task now a standard
-- also if extension installed you can lookup in std comments fast

function _build()
    -- note that directory will not be create if subfolder are missing
    -- this is why we create ./mpbs-cache directory first
    if((std.isExistsLocalDir("./mpbs-cache/") == 0) and (std.createLocalDir("./mpbs-cache/") == 0)) then
        std.info("Failed to create <cache> directory")
    end

    -- also exists std.isExistsLocalFile
    if(std.isExistsLocalDir(output_path) == 1) then
        std.info("Directory found, deleting...")
        if(std.deleteLocalDirOrFile(output_path) == 0) then
            std.info("Failed to delete output directory")
        end
    end

    if(std.createLocalDir(output_path) == 0) then
        std.info("Failed to create output directory")
    end

    build_file("./src/main.cpp")
    build_file("./src/test.cpp")
    std.execute(final_command)
end

function _run()
    _build()
    std.execute(output_executable)
end

-- now register defined function above, because how lua C library works
-- the third argument is function name that defined in global space
-- in current case is the function above that starts with "_"
std.registerTask("build", "Builds a project", "_build")
std.registerTask("run",   "Runs a project",   "_run")
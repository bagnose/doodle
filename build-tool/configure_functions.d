// Functions used by various configure scripts to set up a build environment
// suitable for building with bob and running/deploying.
//
// Expected to be called from a configure.d in a project directory with code like
// the following abbreviated example:
/*
void main(string args[]) {
    auto data = initialise(args, "project-name");

    usePackage(data, "libssh2", Constraint.AtLeast, "1.2");
    useHeader( data, "gcrypt.h");
    useLibrary(data, "libgcrypt.so");
    useExecutable(data, "IMAGE_MAGICK_CONVERT", ["convert"]);

    appendRunVar(data, "GST_PLUGIN_PATH", ["${DIST_PATH}/lib/plugins"]);
    appendBobVar(data, "CCFLAGS", ["-DUSE_BATHY_CHARTING_RASTER_SOURCE"]);

    finalise(data, ["open", "reuse"]); // all packages in this and specified other repos
}
*/


module configure_functions;

import std.string;
import std.getopt;
import std.path;
import std.file;
import std.process;
import std.stdio;
import std.conv;

import core.stdc.stdlib;
import core.sys.posix.sys.stat;




private void setMode(string path, uint mode) {
    chmod(toStringz(path), mode);
}


//
// Config - a data structure to accumulate configure information.
//

enum Priority { User, Env, Project, System } // highest priority first
enum Use      { Inc, Bin, Lib, Pkg }

struct Config {
    int                     verboseConfigure;
    string                  buildLevel;
    string                  productVersion;
    string                  backgroundCopyright;
    string                  foregroundCopyright;
    string                  buildDir;
    bool[string]            architectures;
    string[][Priority][Use] dirs;
    string[][Use]           prevDirs;
    string[][string]        bobVars;
    string[][string]        runVars;
    string[][string]        buildVars;
    string                  reason;
    string[]                configureOptions;
    string                  srcDir;
}

bool[string] barred;


//
// Return the paths that the linker (ld) searches for libraries.
//
string[] linkerSearchPaths() {
    // Note 1: The method used is quite hacky and probably very non-portable.
    // Note 2: An alternative method (no less hacky) would parse the linker script
    // for SEARCH_DIR commands.
    string improbable_name = "this_is_an_extremely_improbable_library_name";
    string command_base = "LIBRARY_PATH= LD_LIBRARY_PATH= ";
    command_base ~= "ld --verbose -lthis_is_an_extremely_improbable_library_name < /dev/null";
    // First command is to check that ld is working and giving the expected error message
    // Something about the ld command means the output must be piped through something (e.g. "cat -")
    // otherwise std.process.shell() will throw 'Could not close pipe'.
    string expected_message = "ld: cannot find -l" ~ improbable_name;
    string command_1 = command_base ~ " 2>&1 > /dev/null | cat -";

    // Second command is to get the output containing the paths that ld searches for libraries.
    string good_prefix = "attempt to open ";
    string good_suffix = "lib" ~ improbable_name ~ ".so failed";
    string command_2 = command_base ~ " 2> /dev/null | grep '^" ~ good_prefix ~ ".*" ~ good_suffix ~ "$'";

    string[] result;
    try {
        //writefln("command_1=%s\n", command_1);
        string[] ld_lines = std.string.splitLines(std.process.shell(command_1));
        //if (expected_message in ld_lines) {
        bool success = false;
        foreach (line; ld_lines) {
            if (line == expected_message) { success = true; break; }
        }
        if (success) {
            //writefln("command_2=%s\n", command_2);
            ld_lines = std.string.splitLines(std.process.shell(command_2));
            foreach (line; ld_lines) {
                if (line.length > good_prefix.length + good_suffix.length + 1) {
                    if (line[0 .. good_prefix.length] == good_prefix &&
                        line[$-good_suffix.length .. $] == good_suffix) {
                        //writefln("Match: \"%s\"", line);
                        result ~= line[good_prefix.length .. $-good_suffix.length-1];
                    }
                }
            }
            return result;
        }
        else {
            writefln("Did not get expected output from ld...\ncommand=%s\noutput:", command_1);
            foreach (line; ld_lines) { writefln(line); }
            exit(1);
        }
    }
    catch (Exception ex) {
        writefln("Error running ld: %s", ex);
        exit(1);
    }
    assert(0); // TODO Why aren't the above exit() calls adequate to satisfy the compiler?
}


//
// Append some tokens to the end of a bob, run or build variable,
// appending only if not already present and preserving order.
//
private void appendVar(ref string[] strings, string[] extra) {
    foreach (string item; extra) {
        if (item in barred) continue;
        bool got = false;
        foreach (string have; strings) {
            if (item == have) {
                got = true;
                break;
            }
        }
        if (!got) {
            strings ~= item;
        }
    }
}
void appendBobVar(ref Config data, string var, string[] tokens) {
    if (data.verboseConfigure >= 2) { writefln("appendBobVar: %s %s", var, tokens); }
    if (var !in data.bobVars) {
        data.bobVars[var] = null;
    }
    appendVar(data.bobVars[var], tokens);
}
void appendRunVar(ref Config data, string var, string[] tokens) {
    if (data.verboseConfigure >= 2) { writefln("appendRunVar: %s %s", var, tokens); }
    if (var !in data.runVars) {
        data.runVars[var] = null;
    }
    appendVar(data.runVars[var], tokens);
}
void appendBuildVar(ref Config data, string var, string[] tokens) {
    if (data.verboseConfigure >= 2) { writefln("appendBuildVar: %s %s", var, tokens); }
    if (var !in data.buildVars) {
        data.buildVars[var] = null;
    }
    appendVar(data.buildVars[var], tokens);
}


//
// Return the join of paths with extra
//
string[] joins(string[] paths, string extra) {
    string[] result;
    foreach (path; paths) {
        result ~= buildPath(path, extra);
    }
    return result;
}


//
// Return a string array of tokens parsed from a number of environment variables, using ':' as delimiter.
// Duplicated are discarded.
//
string[] fromEnv(string[] variables) {
    string[] result;
    bool[string] present;
    foreach (variable; variables) {
        foreach (token; split(std.process.getenv(variable), ":")) {
            if (token !in present) {
                present[token] = true;
                result ~= token;
            }
        }
    }
    return result;
}



//
// Return a string representing the given tokens as an environment variable declaration
//
string toEnv(string[][Priority] tokens, string name) {
    string result;
    foreach (string[] strings; tokens) {
        foreach (string token; strings) {
            result ~= ":" ~ token;
        }
    }
    if (result && result[0] == ':') {
        result = result[1..$];
    }
    if (result) {
        result = name ~ "=\"" ~ result ~ "\"";
    }
    return result;
}


//
// Output (to console) the current search paths being used to locate dependencies.
//
void printSearchDirs(ref string[][Priority][Use] dirs) {
    foreach (Use use, string[][Priority] v; dirs) {
        writefln("%s", use);
        foreach (Priority p, string[] a; v) {
            writefln("  %s: %s", std.string.rightJustify(std.conv.to!string(p), 7), a);
        }
    }
}


//
// Set project-specific directories to look in for required files
//
void setProjectDirs(ref Config data, string[][Use] projectDirs) {
    if (data.verboseConfigure >= 3) { writefln("Updating project search paths:"); }
    foreach (Use use, string[] dirs; projectDirs) {
        data.prevDirs[use] = dirs;
        data.dirs[use][Priority.Project] = dirs;
        if (data.verboseConfigure >= 3) { writefln("Project %s: %s", use, dirs); }
    }
}

//
// Restore project-specific dirs - only one level of restoration available
//
void restoreProjectDirs(ref Config data) {
    if (data.verboseConfigure >= 3) { writefln("Restoring project search paths:"); }
    foreach (Use use, string[] dirs; data.prevDirs) {
        data.prevDirs[use] = dirs;
        data.dirs[use][Priority.Project] = dirs;
        if (data.verboseConfigure >= 3) { writefln("Project %s: %s", use, dirs); }
    }
}


//
// Locate an executable (which can have any of the specified names)
// in any of the dirs listed in data.dirs[Use.Bin], and:
// * set the executable name to bobVar id so bob can run it efficiently.
// * add the dir to runVar PATH, providing acces to other exes in the same dir.
//
string useExecutable(ref Config data, string id, string[] names) {
    foreach (string[] dirs; data.dirs[Use.Bin]) {
        foreach (string dir; dirs) {
            foreach (name; names) {
                if (exists(buildPath(dir, name))) {
                    appendBobVar(data, id, [buildPath(dir, name)]);
                    appendRunVar(data, "PATH", [dir]);
                    if (data.verboseConfigure >= 1) { writefln("Found exe %s as %s in %s", id, name, dir); }
                    return dir;
                }
            }
        }
    }
    data.reason ~= format("Could not find executable %s by names %s\n", id, names);
    return "";
}


//
// Locate an include file in any of data.dirs[Use.Inc], and:
// * add the header dir to bobVar HEADERS
//
string useHeader(ref Config data, string name) {
    foreach (string[] dirs; data.dirs[Use.Inc]) {
        foreach (string dir; dirs) {
            if (exists(buildPath(dir, name))) {
                appendBobVar(data, "HEADERS", [dir]);
                if (data.verboseConfigure >= 1) { writefln("Found header <%s> in %s", name, dir); }
                return dir;
            }
        }
    }
    data.reason ~= "Could not find header " ~ name ~ "\n";
    return "";
}


//
// Locate a library file in any of data.dirs[Use.Lib], and:
// * add library dir to bobVar LINKFLAGS (with '-L' prefix)
// * Not add library dir to buildVar LIBRARY_PATH (Not necessary if adding -L dir to LINKFLAGS)
// * add library dir to runVar LD_LIBRARY_PATH
//
string useLibrary(ref Config data, string name) {
    foreach (string[] dirs; data.dirs[Use.Lib]) {
        foreach (string dir; dirs) {
            if (exists(buildPath(dir, name))) {
                appendBobVar(data, "LINKFLAGS", ["-L" ~ dir]);
                appendRunVar(data, "LD_LIBRARY_PATH", [dir]);
                if (data.verboseConfigure >= 1) { writefln("Found library %s in %s", name, dir); }
                return dir;
            }
        }
    }
    data.reason ~= "Could not find library " ~ name ~ "\n";
    return "";
}


//
// Locate a package .pc file in any of data.dirs[Use.Pkg], and
// use pkg-config to:
// * add library dir to bobVar LINKFLAGS
// * Not add library dir to buildVar LIBRARY_PATH (Not necessary if adding -L dir to LINKFLAGS)
// * add library dir to runVar LD_LIBRARY_PATH
//
enum Constraint { Exists, AtLeast, Exact, Max }
void usePackage(ref Config data,
                string     name,
                Constraint constraint = Constraint.Exists,
                string     ver        = "") {
    string[] constraints = ["--exists", "--atleast-version=", "--exact-version=", "--max-version="];
    try {
        string prefix = toEnv(data.dirs[Use.Pkg], "PKG_CONFIG_PATH");

        // disable use of "uninstalled" packages (which would otherwise silently be used in preference!)
        if (prefix && prefix.length != 0) { prefix ~= " "; }
        prefix ~= "PKG_CONFIG_DISABLE_UNINSTALLED=1";

        //writefln("prefix=%s", prefix);

        string command;

        command = prefix ~ " pkg-config " ~ constraints[constraint] ~ ver ~ " " ~ name;
        //writefln("command=%s", command);
        shell(command);

        command = prefix ~ " pkg-config --cflags " ~ name;
        //writefln("command=%s", command);
        string ccflags = shell(command);
        foreach (flag; split(ccflags)) {
            if (flag.length > 2 && flag[0..2] == "-I") {
                appendBobVar(data, "HEADERS", [flag[2..$]]);
            }
            else {
                appendBobVar(data, "CCFLAGS", [flag]);
            }
        }

        command = prefix ~ " pkg-config --libs-only-L " ~ name;
        //writefln("command=%s", command);
        string linkflags = shell(command);
        appendBobVar(data, "LINKFLAGS", split(linkflags));
        foreach (flag; split(linkflags)) {
            if (flag.length > 2 && flag[0..2] == "-L") {
                //appendBuildVar(data, "LIBRARY_PATH", [flag[2..$]]);  not necessary
                appendRunVar(data, "LD_LIBRARY_PATH", [flag[2..$]]);
            }
        }

        if (data.verboseConfigure >= 1) {
            command = prefix ~ " pkg-config --modversion " ~ name;
            //writefln("command=%s", command);
            string modVersion = shell(command);
            writefln("Found package %s (v%s)", name, chomp(modVersion));
        }
    }
    catch (Exception ex) {
        data.reason ~= "Could not find package " ~ constraints[constraint] ~ " " ~ ver ~ " " ~ name ~ "\n";
    }
}


//
// Locate a corba-tao library in any of data.dirs[Use.Lib], provide access to
// required TAO utilities, and set required variables.
//
void useTao(ref Config data) {
    string incdir = useHeader(data, "tao/corba.h");

    useLibrary(data, "libTAO.so");

    useExecutable(data, "TAO_IDL",                    ["tao_idl"]);
    useExecutable(data, "TAO_NAMING_SERVICE",         ["Naming_Service"]);
    useExecutable(data, "TAO_EVENT_SERVICE",          ["CosEvent_Service"]);
    useExecutable(data, "TAO_INTERFACE_REPO_SERVICE", ["IFR_Service"]);
    useExecutable(data, "TAO_INTERFACE_COMPILER",     ["tao_ifr"]);

    appendBobVar(data, "IDL_HEADERS",            [incdir]);
    appendBobVar(data, "GENERATE_EMPTY_SERVANT", ["false"]);
    appendBobVar(data, "CCFLAGS",                ["-DTAO_HAS_TYPED_EVENT_CHANNEL"]);
    appendRunVar(data, "ACE_ROOT",               [dirName(incdir)]);
    appendRunVar(data, "TAO_ROOT",               [buildPath(dirName(incdir), "TAO")]);
}


//
// Parse command-line arguments and return resultant Config data
//
Config initialise(string[] args, string projectPackage) {

    // check that we are in the project directory
    if (!exists("configure.d")) {
        writefln("Configure must be run from the project directory, which contains configure.d");
        exit(1);
    }

    // parse arguments

    bool     help;
    int      verboseConfigure;
    string   buildLevel = "release";
    string   productVersion = "development from " ~ getcwd;
    string[] architectures;
    string[] packagePrefixes;

    immutable bool[string] validArchitectures = ["Ubuntu":true, "CentOS-4":true, "CentOS-5":true];

    Config data;
    auto argsCopy = args.dup; // remember the arguments

    try {
        getopt(args, std.getopt.config.caseSensitive,
               "help|h",         &help,
               "verbose+",       &verboseConfigure,
               "build",          &buildLevel,
               "product|p",      &productVersion,
               "architecture|a", &architectures,
               "package-prefix", &packagePrefixes);
    }
    catch (Exception ex) {
        writefln("Invalid argument(s): %s", ex.msg);
        help = true;
    }

    if (help || args.length < 2) {
        writefln("Usage: configure [options] build-dir-path\n"
                 "  --help                display this message\n"
                 "  --verbose             display more configure messages (multiple)\n"
                 "  --build=level         build level: debug, integrate, release (default) or profile\n"
                 "  --product=version     sets product version\n"
                 "  --architecture=arch   sets architecture for conditional Bobfile rules (multiple)\n"
                 "  --package-prefix=path looks for locally installed packages at path (multiple)\n");
        exit(1);
    }
    foreach (arch; architectures) {
        if (arch !in validArchitectures) {
            writefln("%s is not one of these valid architectures: %s",
                     arch, validArchitectures.keys());
            exit(1);
        }
        data.architectures[arch] = true;
    }

    string buildDir = args[1];


    //
    // populate and return config data
    //

    data.srcDir = std.file.getcwd();

    foreach (arg; argsCopy[1..$]) {
        if (arg != buildDir) {
            data.configureOptions ~= arg;
        }
    }

    //
    // populate and return config data
    //

    // Populate data.dirs using packagePrefixes, environment variables, hard-coding, etc.
    // The Pritority.Project elements are (re)populated via a call to setProjectDirs.

    // add some "standard" user-specific prefixes to packagePrefixes to make life easier for users
    packagePrefixes ~= ["/opt/acacia/tao", "/opt/acacia/ecw"];

    // System - lowest priority
    data.dirs[Use.Inc][Priority.System] = ["/include", "/usr/include"];
    data.dirs[Use.Bin][Priority.System] = ["/bin", "/sbin", "/usr/bin", "/usr/sbin"];
    data.dirs[Use.Lib][Priority.System] = linkerSearchPaths(); // ["/lib", "/usr/lib"];
    data.dirs[Use.Pkg][Priority.System] = null; // /usr/lib/pkgconfig is automatically used

    // Prevent System paths from being added to the output
    foreach (Use use, string[][Priority] v; data.dirs) {
        foreach (Priority p, string[] a; v) {
            foreach (string b; a) {
                barred[b] = true;
            }
        }
    }
    // Extra protection required for library paths
    foreach (string v; data.dirs[Use.Lib][Priority.System]) {
        barred["-L" ~ v] = true;
    }

    // Project - medium priority, set by call to setProjectDirs
    data.dirs[Use.Inc][Priority.Project] = null;
    data.dirs[Use.Bin][Priority.Project] = null;
    data.dirs[Use.Lib][Priority.Project] = null;
    data.dirs[Use.Pkg][Priority.Project] = null;

    // Env - high priority
    data.dirs[Use.Inc][Priority.Env] = fromEnv(["CPATH"]);
    data.dirs[Use.Bin][Priority.Env] = fromEnv(["PATH"]);
    data.dirs[Use.Lib][Priority.Env] = fromEnv(["LD_LIBRARY_PATH"/*, "LIBRARY_PATH"*/]);
    data.dirs[Use.Pkg][Priority.Env] = fromEnv(["PKG_CONFIG_PATH"]);

    // User - highest priority
    data.dirs[Use.Inc][Priority.User] = joins(packagePrefixes, "include");
    data.dirs[Use.Bin][Priority.User] = joins(packagePrefixes, "bin");
    data.dirs[Use.Lib][Priority.User] = joins(packagePrefixes, "lib");
    data.dirs[Use.Pkg][Priority.User] = joins(packagePrefixes, "lib/pkgconfig");

    // Print the search paths (better to do this elsewhere/when)
    if (verboseConfigure >= 3) { writefln("Initial search paths:"); printSearchDirs(data.dirs); }

    // assorted variables

    data.verboseConfigure = verboseConfigure;
    data.buildLevel       = buildLevel;
    data.productVersion   = productVersion;
    // TODO? Automatically insert the current year?
    data.backgroundCopyright =
        "Part or all of this software is © Copyright 1995-2011 Acacia Research Pty Ltd. "
        "All rights reserved.\\n"
        "This software may utilise third party libraries from various sources.\\n"
        "These libraries are copyrighted by their respective owners.";
    data.foregroundCopyright =
        "Parts of this software are foreground intellectual property. ";

    data.buildDir = buildDir;

    appendBobVar(data, "PROJECT-PACKAGE", [projectPackage]);

    appendBobVar(data, "LINKFLAGS", ["-lstdc++", "-rdynamic"]);

    appendBobVar(data, "DEXTERNALS", ["std", "core"]);

    appendBobVar(data, "DFLAGS", ["-w", "-wi"]);

    appendBobVar(data, "CCFLAGS",
                 ["-fPIC",
                 "-pedantic",
                 "-Werror",
                 "-Wall",
                 "-Wno-long-long",
                 "-Wundef",
                 "-Wredundant-decls"]);

    if (data.buildLevel == "debug") {
        appendBobVar(data, "DFLAGS", ["-gc"]);
        appendBobVar(data, "CCFLAGS",
                     ["-O1",
                     "-DACRES_DEBUG=1",
                     "-DACRES_INTEGRATE=1",
                     "-fno-omit-frame-pointer",
                     "-ggdb3"]);
    }
    else if (data.buildLevel == "integrate") {
        appendBobVar(data, "DFLAGS", ["-O"]);
        appendBobVar(data, "CCFLAGS",
                     ["-O1",
                     "-DACRES_DEBUG=0",
                     "-DACRES_INTEGRATE=1",
                     "-DNDEBUG",
                     "-fno-omit-frame-pointer",
                     "-Wno-unused-variable"]);
    }
    else if (data.buildLevel == "profile") {
        appendBobVar(data, "DFLAGS", ["-O"]);
        appendBobVar(data, "CCFLAGS",
                     ["-O2",
                     "-DACRES_DEBUG=0",
                     "-DACRES_INTEGRATE=0",
                     "-DNDEBUG",
                     "-fno-omit-frame-pointer",
                     "-Wno-unused-variable",
                     "-ggdb3"]);
    }
    else if (data.buildLevel == "release") {
        appendBobVar(data, "DFLAGS", ["-O", "-release"]);
        appendBobVar(data, "CCFLAGS",
                     ["-O2",
                     "-DACRES_DEBUG=0",
                     "-DACRES_INTEGRATE=0",
                     "-DNDEBUG",
                     "-fno-omit-frame-pointer",
                     "-Wno-unused-variable"]);
    }
    else {
        writefln("unsupported build level '%s'", data.buildLevel);
        exit(1);
    }

    appendBobVar(data, "C++FLAGS",
                 ["-Woverloaded-virtual",
                 "-Wsign-promo",
                 "-Wctor-dtor-privacy",
                 "-Wnon-virtual-dtor"]);

    appendBobVar(data, "VALID_ARCHITECTURES", validArchitectures.keys);
    appendBobVar(data, "ARCHITECTURES",       architectures);

    /*
    useExecutable(data, "RST2HTML", ["rst2html.py", "rst2html", "docutils-rst2html.py"]);
    */

    appendRunVar(data, "LD_LIBRARY_PATH",  [`${DIST_PATH}/lib`]);
    appendRunVar(data, "LD_LIBRARY_PATH",  [`${DIST_PATH}/lib/plugins`]);
    appendRunVar(data, "SYSTEM_DATA_PATH", [`${DIST_PATH}/data`]);
    appendRunVar(data, "PATH", [`${DIST_PATH}/bin`]);

    return data;
}


// Write the content to the file if file doesn't already match (and optionally set executable).
// File is created if it doesn't exist.
void update(ref Config data, string name, string content, bool executable) {
    string path = buildPath(data.buildDir, name);
    bool clean = false;
    if (exists(path)) {
        string current = cast(string) std.file.read(path);
        clean = (current == content);
    }
    if (!clean) {
        if (data.verboseConfigure >= 2) { writefln("Setting content of %s", name); }
        std.file.write(path, content);
    }
    if (executable) {
        uint exeMode = octal!700;
        uint attr = getAttributes(path);
        if ((attr & exeMode) != exeMode) {
            if (data.verboseConfigure >= 4) { writefln("Setting exe mode on %s", name); }
            setMode(path, exeMode | attr);
        }
    }
}


//
// Set up build environment as specified by data, or issue error messages and bail
//
// repos are repository names in sibling directories to the directory containing
// the configure script.
//
void finalise(ref Config data, string[] otherRepos) {

    // check that all is well, and bail with an explanation if not
    if (data.reason.length) {
        writefln("Configure FAILED because:\n%s\n", data.reason);
        exit(1);
    }

    writefln("Configure checks completed ok - establishing build directory...");

    // create build directory
    if (!exists(data.buildDir)) {
        mkdirRecurse(data.buildDir);
    }
    else if (!isDir(data.buildDir)) {
        writefln("Configure FAILED because: %s is not a directory", data.buildDir);
        exit(1);
    }

    // create Boboptions file from bobVars
    string bobText;
    foreach (string key, string[] tokens; data.bobVars) {
        bobText ~= key ~ " = ";
        if (key == "C++FLAGS") {
            // C++FLAGS has all of CCFLAGS too
            foreach (token; data.bobVars["CCFLAGS"]) {
                bobText ~= token ~ " ";
            }
        }
        foreach (token; tokens) {
            bobText ~= token ~ " ";
        }
        bobText ~= ";\n";
    }
    update(data, "Boboptions", bobText, false);

    // create version_info.h file
    string versionText;
    versionText ~= "#ifndef VERSION_INFO__H\n";
    versionText ~= "#define VERSION_INFO__H\n";
    versionText ~= "\n";
    versionText ~= "#define PRODUCT_VERSION \"" ~ data.productVersion ~ "\"\n";
    versionText ~= "#define FOREGROUND_IP_COPYRIGHT_NOTICE \"" ~ data.foregroundCopyright ~ "\"\n";
    versionText ~= "#define BACKGROUND_IP_COPYRIGHT_NOTICE \"" ~ data.backgroundCopyright ~ "\"\n";
    versionText ~= "\n";
    versionText ~= "#endif /* VERSION_INFO__H */\n";
    update(data, "version_info.h", versionText, false);

    // set up string for a fix_env bash function
    string fixText =
`# Remove duplicates and empty tokens from a string containing
# colon-separated tokens, preserving order.
function fix_env () {
    local original="${1}"
    local IFS=':'
    local result=""
    for item in ${original}; do
        if [ -z "${item}" ]; then
            continue
        fi
        #echo "item: \"${item}\"" >&2
        local -i found_existing=0
        for existing in ${result}; do
            if [ "${item}" == "${existing}" ]; then
                found_existing=1
                break 1
            fi
        done
        if [ ${found_existing} -eq 0 ]; then
            result="${result:+${result}:}${item}"
        fi
    done
    echo "${result}"
}
`;

    // create environment-run file
    string runEnvText;
    runEnvText ~= "# set up the run environment variables\n\n";
    runEnvText ~= fixText;
    runEnvText ~= `if [ -z "${DIST_PATH}" ]; then` ~ "\n";
    runEnvText ~= `    echo "DIST_PATH not set"` ~ "\n";
    runEnvText ~= "    return 1\n";
    runEnvText ~= "fi\n";
    runEnvText ~= "\n";
    foreach (string key, string[] tokens; data.runVars) {
        runEnvText ~= "export " ~ key ~ `="$(fix_env "`;
        foreach (token; tokens) {
            runEnvText ~= token ~ ":";
        }
        runEnvText ~= `${` ~ key ~ `}")"` ~ "\n";
    }
    runEnvText ~= "unset fix_env\n";
    update(data, "environment-run", runEnvText, false);


    // create environment-build file
    string buildEnvText;
    buildEnvText ~= "# set up the build environment variables\n\n";
    buildEnvText ~= fixText;
    buildEnvText ~=
`if [ ! -z "${DIST_PATH}" ]; then
    echo "ERROR: DIST_PATH set when building"
    return 1
fi
export DIST_PATH="${PWD}/dist"
`;
    foreach (string key, string[] tokens; data.buildVars) {
        buildEnvText ~= "export " ~ key ~ `="$(fix_env "`;
        foreach (token; tokens) {
            buildEnvText ~= token ~ ":";
        }
        buildEnvText ~= `${` ~ key ~ `}")"` ~ "\n";
    }
    buildEnvText ~= "unset fix_env\n";
    buildEnvText ~= "# also pull in the run environment\n";
    buildEnvText ~= "source ./environment-run\n";
    update(data, "environment-build", buildEnvText, false);


    // create build script
    string buildText =
`#!/bin/bash

source ./environment-build

# Rebuild the bob executable if necessary
BOB_SRC="./src/build-tool/bob.d"
BOB_EXE="./.bob/bob"
if [ ! -e ${BOB_EXE} -o ${BOB_SRC} -nt ${BOB_EXE} ]; then
    echo "Compiling build tool."
    dmd -O -gc -w -wi ${BOB_SRC} -of${BOB_EXE}
    if [ $? -ne 0 ]; then
        echo "Failed to compile the build tool..."
        exit 1
    else
        echo "Build tool compiled successfully."
    fi
fi

# Test if we are running under eclipse
# Cause bob to echo commands passed to compiler to support eclipse auto discovery.
# Also change the include directives to those recognised by eclipse CDT.
if [ "$1" = "--eclipse" ] ; then
    shift
    echo "NOTE: What is displayed here on the console is not exactly what is executed by g++"

    ${BOB_EXE} --actions "$@" 2>&1 | sed -re "s/-iquote|-isystem/-I/g"
else
    ${BOB_EXE} "$@"
fi
`;
    update(data, "build", buildText, true);


    // create clean script
    string cleanText =
`#!/bin/bash

if [ $# -eq 0 ]; then
    rm -rf ./dist ./priv ./obj
else
    echo "Failed: $(basename ${0}) does not accept arguments - it cleans everything."
    exit 2
fi
`;
    update(data, "clean", cleanText, true);


    // strings containing common parts of run-like scripts
    string runPrologText =
`#!/bin/bash

export DIST_PATH="${PWD}/dist"
source ./environment-run
exe=$(which "$1" 2> /dev/null)

if [ -z "${exe}" ]; then
    echo "Couldn't find \"$1\"" >&2
    exit 1
fi
export TMP_PATH="$(dirname ${exe})/tmp-$(basename ${exe})"
`;


    // create (exuberant) ctags config file
    string dotCtagsText =
`--langdef=IDL
--langmap=IDL:+.idl
--regex-IDL=/^[ \t]*module[ \t]+([a-zA-Z0-9_]+)/\1/n,module,Namespace/e
--regex-IDL=/^[ \t]*enum[ \t]+([a-zA-Z0-9_]+)/\1/g,enum/e
--regex-IDL=/^[ \t]*struct[ \t]+([a-zA-Z0-9_]+)/\1/c,struct/e
--regex-IDL=/^[ \t]*exception[ \t]+([a-zA-Z0-9_]+)/\1/c,exception/e
--regex-IDL=/^[ \t]*interface[ \t]+([a-zA-Z0-9_]+)/\1/c,interface/e
--regex-IDL=/^[ \t]*typedef[ \t]+[a-zA-Z0-9_:\*<> \t]+[ \t]+([a-zA-Z0-9_]+)[ \t]*;/\1/t,typedef/e
--regex-IDL=/^[ \t]*[a-zA-Z0-9_:]+[ \t]+([a-zA-Z0-9_]+)[ \t]*[;]/\1/v,variable/e
`;
    update(data, ".ctags", dotCtagsText, false);


    // create make-tags script
    string makeCtagsText =
`#!/bin/bash

SOURCE_DIR="src"
TAGS_FILE="tags"

find -H "${SOURCE_DIR}"/* -xdev \( \( -type d -name \.svn \) -prune \
            -o -name \*.cc -o -name \*.h -o -name \*.ccg -o -name \*.hg -o -name \*.hpp -o -name \*.cpp \
            -o -name \*.inl -o -name \*.i \
            -o -name \*.idl \) |
grep -v ".svn" |
# maybe add other grep commands here
ctags -f "${TAGS_FILE}" -h default --langmap="c++:+.hg.ccg.inl.i" --extra=+f+q --c++-kinds=+p --tag-relative=yes --totals=yes --fields=+i -L -
`;
    update(data, "make-tags", makeCtagsText, true);


    // create make-cooked-tags script
    string makeCookedCtagsText =
`#!/bin/bash

SOURCE_DIR="obj"
TAGS_FILE="cooked-tags"

find -H "${SOURCE_DIR}"/* -xdev \( \( -type d -name \.svn \) -prune \
            -o -name \*.cc -o -name \*.h -o -name \*.ccg -o -name \*.hg -o -name \*.hpp -o -name \*.cpp \
            -o -name \*.idl \) |
grep -v ".svn" |
# maybe add other grep commands here
ctags -f "${TAGS_FILE}" -h default --langmap="c++:+.hg.ccg" --extra=+f+q --c++-kinds=+p --tag-relative=yes --totals=yes --fields=+i -L -
`;
    update(data, "make-cooked-ctags", makeCookedCtagsText, true);


    // create test script
    string testText;
    testText ~= runPrologText;
    testText ~=
`
if [ $# -ne 1 ]; then
    echo "The test script doesn't support arguments to test executable." >&2
    echo "Given: ${@}" >&2
    exit 2
fi
declare -i return_value=1

run_test() {
    # remove results and run the test to make some more
    set -o pipefail
    rm -f ${exe}-*

    # Ensure the result file is not zero-length (Bob depends on this)
    echo ${exe} > ${exe}-result
    ${exe}     >> ${exe}-result 2>&1

    # generate passed or failed file
    if [ "$?" != "0" ]; then
        mv ${exe}-result ${exe}-failed
        echo "${exe}-failed:1: error: test failed"
        cat ${exe}-failed
        exit 1
    else
        mv ${exe}-result ${exe}-passed    
        rm -rf ${TMP_PATH}
    fi
}

rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && run_test
`;
    update(data, "test", testText, true);


    // create run script
    string runText;
    runText ~= runPrologText;
    runText ~= "rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && exec \"$@\"";
    update(data, "run", runText, true);

    if (data.buildLevel == "profile") {
        // create perf script
        string perfText;
        perfText ~= runPrologText;
        perfText ~= "echo after exiting, run 'perf report' to see the result\n";
        perfText ~= "rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && exec perf record -g -f $@\n";
        update(data, "perf", perfText, true);
    }

    if (data.buildLevel != "release") {
        // create gdb script
        string gdbText;
        gdbText ~= runPrologText;
        gdbText ~= "rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && exec gdb --args $@\n";
        update(data, "gdb", gdbText, true);

        // create nemiver script
        string nemiverText;
        nemiverText ~= runPrologText;
        nemiverText ~= "rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && exec nemiver $@\n";
        update(data, "nemiver", nemiverText, true);
    }

    // create valgrind script
    string valgrindText;
    valgrindText ~= runPrologText;
    valgrindText ~= "rm -rf ${TMP_PATH} && mkdir ${TMP_PATH} && exec valgrind $@\n";
    update(data, "valgrind", valgrindText, true);


    //
    // create src directory with symbolic links to all top-level packages in all
    // specified repositories
    //

    // make src dir
    string srcPath = buildPath(data.buildDir, "src");
    if (!exists(srcPath)) {
        mkdir(srcPath);
    }

    // make a symbolic link to each top-level package in this and other specified repos
    string[string] pkgPaths;  // package paths keyed on package name
    string project = dirName(getcwd);
    foreach (string repoName; otherRepos ~ baseName(getcwd)) {
        string repoPath = buildPath(project, repoName);
        if (isDir(repoPath)) {
            //writefln("adding source links for packages in repo %s", repoName);
            foreach (string path; dirEntries(repoPath, SpanMode.shallow)) {
                string pkgName = baseName(path);
                if (isDir(path) && pkgName[0] != '.') {
                    //writefln("  found top-level package %s", pkgName);
                    assert(pkgName !in pkgPaths,
                           format("Package %s found at %s and %s",
                                  pkgName, pkgPaths[pkgName], path));
                    pkgPaths[pkgName] = path;
                }
            }
        }
    }
    foreach (name, path; pkgPaths) {
        string linkPath = buildPath(srcPath, name);
        system(format("rm -f %s; ln -sn %s %s", linkPath, path, linkPath));
    }

    // print success
    writefln("Build environment in %s is ready to roll", data.buildDir);
}


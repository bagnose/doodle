import std.stdio;
import std.string;
import std.exception;
import std.algorithm;
import std.file;
import std.md5;
import std.getopt;
import std.conv;
import std.ascii;
import std.c.stdlib;

ulong string_to_size(string s) {
    // Convert strings to sizes, eg:
    //   "50"   -> 50
    //   "80B"  -> 80
    //   "10K"  -> 10240
    //   "1M"   -> 1048576
    // Throws ConvException

    immutable map = [ 'B':1UL, 'K':1UL<<10, 'M':1UL<<20, 'G':1UL<<30, 'T':1UL<<40 ];

    if (s.length == 0) {
        throw new ConvException("Empty string");
    }
    else {
        ulong multiplier = 1;

        if (isAlpha(s[$-1])) {
            immutable ulong * m = (s[$-1] in map);

            if (m) {
                multiplier = *m;
            }
            else {
                throw new ConvException(format("Bad size unit character: %s", s[$-1]));
            }

            s = s[0..$-1];
        }

        return multiplier * to!ulong(s);
    }
}

string size_to_string(in ulong size) {
    /+
    immutable array = [ 'B', 'K', 'M', 'G', 'T' ];
    size_t index = 0;

    foreach (i, c; array) {
        if (size / (1UL << i

        writefln("%s %s", i, c);
    }
    +/

    return format("%sK", size / 1024);
}

void find_duplicates(in string[] dirs,
                     in ulong    file_size,
                     in ulong    digest_size,
                     bool        verbose) {
    static ubyte[16] compute_md5(in string filename, in ulong max_bytes) {
        size_t chunk_size = min(max_bytes, 4096 * 1024);
        ubyte[16] digest;

        auto file = File(filename, "r");
        scope(exit) file.close();

        MD5_CTX context;
        context.start();
        ulong byte_count = 0;
        foreach (ubyte[] buffer; chunks(file, chunk_size)) {
            context.update(buffer);
            byte_count += buffer.length;
            if (byte_count >= max_bytes) {
                break;
            }
        }
        context.finish(digest);

        return digest;
    }

    struct FileInfo {
        string name;
        ulong  size;
    }

    FileInfo[] file_array;

    writefln("Accumulating file list");

    foreach (string dir; dirs) {
        if (isDir(dir)) {
            string last_entry;
            try {
                foreach (string filename; dirEntries(dir, SpanMode.depth, false)) {
                    last_entry = filename;
                    try {
                        if (!isSymlink(filename) && isFile(filename)) {
                            ulong size = getSize(filename);
                            if (size >= file_size) {
                                file_array ~= FileInfo(filename, size);
                            }
                        }
                    }
                    catch (Exception ex) {
                        writefln("Skipping %s", filename);
                        //writefln("Exception %s", ex);
                        // TODO accumulate errors and print after traversal
                    }
                }
            }
            catch (FileException ex) {
                // ignore
                writefln("Error, dirEntries bailed out after: %s. Continuing anyway", last_entry);
            }
        }
        else {
            writefln("Not a dir: %s", dir);
        }
    }

    writefln("Processing %s files", file_array.length);

    uint[][ulong] size_to_file_indices;
    bool[ulong]   duplicate_sizes;

    foreach (uint index, file; file_array) {
        //writefln("%s %s %s", index, file.name, file.size);

        if (uint[] * indices = (file.size in size_to_file_indices)) {
            if (indices.length == 1) {
                // Second time we've seen a file of this size,
                // record it in the duplicate_sizes array
                duplicate_sizes[file.size] = true;
            }

            (*indices) ~= index;
        }
        else {
            size_to_file_indices[file.size] = [ index ];
        }
    }

    writefln("Number of files of duplicate size %s", duplicate_sizes.length);

    ulong total_waste = 0;

    foreach_reverse (size; duplicate_sizes.keys.sort) {
        uint[] indices = size_to_file_indices[size];
        //writefln("For size %s there are %s files", size, indices.length);

        uint[][ubyte[16]] digest_to_indices;

        foreach (index; indices) {
            const FileInfo file_info = file_array[index];

            try {
                ubyte[16] digest = compute_md5(file_info.name, digest_size);

                if (uint[] * duplicate_indices = (digest in digest_to_indices)) {
                    // A true duplicate
                    // index and index2 are the same

                    (*duplicate_indices) ~= index;
                }
                else {
                    digest_to_indices[digest] ~= index;
                }
            }
            catch (ErrnoException ex) {
                //writefln("Skipping: %s", file_info.name);
            }

            //writefln("\t%s", file_info.name);
        }

        foreach (indices2; digest_to_indices) {
            if (indices2.length > 1) {
                // List the duplicates
                foreach (i, index; indices) {
                    FileInfo file_info = file_array[index];
                    if (i == 0) {
                        writefln("%s", size_to_string(file_info.size));
                        total_waste += file_info.size;
                    }
                    writefln("    %s", file_info.name);
                }
                writefln("");
            }
        }
    }

    writefln("Done, total waste: %s", size_to_string(total_waste));
}

int main(string[] args) {
    ulong file_size;
    ulong digest_size;
    bool  verbose;

    try {
        string file_size_string   = "100K";
        string digest_size_string = "100K";

        void help(in string) {
            writefln("Usage: dupes [OPTION]... DIR...\n"
                     "Recursively locate duplicate files in a list of directories\n"
                     "\n"
                     "Options\n"
                     " -d, --digest-size=SIZE     size of digest used for comparison [%s]\n"
                     " -f, --file-size=SIZE       minimum size of files searched for duplication [%s]\n"
                     " -v, --verbose              be verbose\n"
                     "     --help                 display this help and exit\n"
                     "\n"
                     "SIZE is an integer, optionally followed by K, M, G, T",
                     file_size_string,
                     digest_size_string);
            exit(1);
        }

        getopt(args,
               "file-size|f",   &file_size_string,
               "digest-size|d", &digest_size_string,
               "verbose|v",     &verbose,
               "help",          &help);

        file_size   = string_to_size(file_size_string);
        digest_size = string_to_size(digest_size_string);
    }
    catch (ConvException ex) {
        writefln("Conversion error: %s", ex);
        exit(2);
    }

    if (verbose) {
        writefln("file-size=%s, digest-size=%s", size_to_string(file_size), size_to_string(digest_size));
    }

    find_duplicates(args[1..$], file_size, digest_size, verbose);

    return 0;
}

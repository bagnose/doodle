import std.stdio;
import std.path;
import std.string;
import std.exception;
import std.algorithm;
import std.file;
import std.digest.md;
import std.getopt;
import std.conv;
import std.ascii;
import std.c.stdlib;

// Convert strings to sizes, eg:
//   "50"   -> 50
//   "80B"  -> 80
//   "10K"  -> 10240
//   "1M"   -> 1048576
// Throws ConvException
ulong stringToSize(string s) {
    immutable map = [
        'B':1UL,
        'K':1UL<<10, 'M':1UL<<20, 'G':1UL<<30,
        'T':1UL<<40, 'P':1UL<<50, 'E':1UL<<60
        ];

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

            s = s[0 .. $-1];
        }

        return multiplier * to!ulong(s);
    }
}

// Convert size to strings, eg:
//   10240 -> "10K"
string sizeToString(in ulong size) {
    static int highestBitIndex(ulong value) {
        for (int i = value.sizeof * 8 - 1; i != 0; --i) {
            if ((value >> i) & 1) return i;
        }

        return 0;
    }

    // We don't want 1100 to become 1K, but 11000 can be 11K
    int bitIndex = highestBitIndex(size / 10);

    int unitIndex = bitIndex / 10;
    immutable array = [ 'B', 'K', 'M', 'G', 'T', 'P', 'E' ];

    return format("%s%s", (size >> (unitIndex * 10)), array[unitIndex]);
}

string upDir(in string path, uint dirCount) {
    string result = path;
    for (uint i = 0; i != dirCount; ++i) {
        result = dirName(result);
    }
    return result;
}

void findDuplicates(in string[] dirs,
                    in ulong    minFileSize,
                    in ulong    compareAmount,
                    bool        verbose) {
    alias ubyte[16] Hash;

    static Hash computeHash(in string filename, in ulong maxBytes) {
        //writefln("Computing hash of %s", filename);
        auto file = File(filename, "r");
        scope(exit) file.close();

        MD5 md5;
        ulong byteCount = 0;

        foreach (ubyte[] buffer; chunks(file, 1024 * 4096)) {
            write("#");
            stdout.flush();
            if (maxBytes != 0 && byteCount + buffer.length >= maxBytes) {
                md5.put(buffer[0 .. maxBytes - byteCount]);
                break;
            }
            else {
                md5.put(buffer);
                byteCount += buffer.length;
            }
        }

        Hash hash = md5.finish();
        //writefln(" %s", toHexString(hash));
        writefln(" %s", hash);
        return hash;
    }

    struct FileInfo {
        string name;
        ulong  size;
    }

    static void accumulateFileInfo(in string dir, in ulong minFileSize, ref FileInfo[] fileArray) {
        try {
            //writefln("Dir: %s", dir);
            foreach (string entry; dirEntries(dir, SpanMode.shallow, false)) {
                if (isSymlink(entry)) {
                    continue;
                }

                if (isDir(entry)) {
                    // Recurse
                    accumulateFileInfo(entry, minFileSize, fileArray);
                }
                else if (isFile(entry)) {
                    ulong size = getSize(entry);
                    //writefln("File: %s, %s", entry, sizeToString(size));
                    if (size >= minFileSize) {
                        fileArray ~= FileInfo(entry, size);
                        writef("\r%s", fileArray.length);
                        stdout.flush();
                    }
                }
            }
        }
        catch (FileException ex) {
            writeln(ex.msg);
        }
    }

    FileInfo[] fileArray;

    writefln("Accumulating file list");

    foreach (string dir; dirs) {
        accumulateFileInfo(dir, minFileSize, fileArray);
    }
    writeln();

    writefln("Processing %s files", fileArray.length);

    uint[][ulong] sizeToFileIndices;
    bool[ulong]   duplicateSizes;

    foreach (uint index, file; fileArray) {
        //writefln("%s %s %s", index, file.name, file.size);

        if (uint[] * indicesSameSize = (file.size in sizeToFileIndices)) {
            if (indicesSameSize.length == 1) {
                // Second time we've seen a file of this size,
                // record it in the duplicateSizes array
                duplicateSizes[file.size] = true;
            }

            (*indicesSameSize) ~= index;
        }
        else {
            sizeToFileIndices[file.size] = [ index ];
        }
    }

    writefln("Number of files of duplicate size %s", duplicateSizes.length);

    ulong totalWaste = 0;

    foreach_reverse (size; duplicateSizes.keys.sort) {
        uint[] indicesSameSize = sizeToFileIndices[size];
        //writefln("For size %s there are %s files", size, indicesSameSize.length);

        uint[][Hash] hashToIndices;

        foreach (index; indicesSameSize) {
            const FileInfo fileInfo = fileArray[index];

            try {
                writefln("(%s) %s", sizeToString(fileInfo.size), fileInfo.name);
                Hash hash = computeHash(fileInfo.name, compareAmount);

                if (uint[] * duplicateIndices = (hash in hashToIndices)) {
                    (*duplicateIndices) ~= index;       // a duplicate
                }
                else {
                    hashToIndices[hash] ~= index;       // the first instance
                }
            }
            catch (ErrnoException ex) {
                writeln(ex.msg);
            }
        }

        foreach (indicesSameHash; hashToIndices) {
            if (indicesSameHash.length > 1) {
                // List the duplicates
                foreach (i, index; indicesSameHash) {
                    FileInfo fileInfo = fileArray[index];
                    if (i == 0) {
                        writefln("%s", sizeToString(fileInfo.size));
                        totalWaste += fileInfo.size;
                    }
                    writefln("[%s]\t%s", i, fileInfo.name);
                }
                writef("Select index to keep (deleting others) or enter to ignore (prepend hyphens to ascend dirs): ");
                string s = readln().chomp();

                try {
                    uint dirCount = 0;

                    while (s.length != 0) {
                        if (s[0] == '-') {
                            ++dirCount;
                            s = s[1 .. $];
                        }
                        else {
                            break;
                        }
                    }

                    uint i_keep = to!uint(s);

                    if (i_keep >= 0 && i_keep < indicesSameHash.length) {
                        foreach (i, index; indicesSameHash) {
                            FileInfo fileInfo = fileArray[index];
                            if (i != i_keep) {
                                try {
                                    if (dirCount > 0) {
                                        string dir = upDir(fileInfo.name, dirCount);
                                        writefln(" ** Removing directory: %s", dir);
                                        //rmdirRecurse(dir);
                                    }
                                    else {
                                        writefln(" ** Removing file: %s", fileInfo.name);
                                        //remove(fileInfo.name);
                                    }
                                }
                                catch (Exception ex) {
                                    writefln(ex.msg);
                                }
                            }
                        }
                    }
                }
                catch (ConvException ex) {
                    // Silently ignore
                    //writefln("No good: %s", ex.msg);
                }
            }
        }
    }

    writefln("Done, total waste: %s", sizeToString(totalWaste));
}

int main(string[] args) {
    ulong minFileSize;
    ulong compareAmount;
    bool  verbose;

    try {
        string minFileSizeString   = "1M";
        string compareAmountString = "0";

        void help(in string = "") {
            writefln("Usage: dupes [OPTION]... DIR...\n"
                     "Recursively locate duplicate files in a list of directories\n"
                     "\n"
                     "Options\n"
                     " -m, --min-file-size=SIZE   minimum size of files to be considered [%s]\n"
                     " -c, --compare-amount=SIZE  number of bytes to compare [%s] (0 -> unlimited)\n"
                     "     --help                 display this help and exit\n"
                     "\n"
                     "SIZE is an integer, optionally followed by B, K, M, G, T, P, E",
                     minFileSizeString,
                     compareAmountString);
            exit(1);
        }

        getopt(args,
               "min-file-size|m",  &minFileSizeString,
               "compare-amount|c", &compareAmountString,
               "verbose|v",        &verbose,
               "help",             &help);

        minFileSize   = stringToSize(minFileSizeString);
        compareAmount = stringToSize(compareAmountString);

        if (verbose) {
            writefln("min-file-size=%s, compare-amount=%s",
                     sizeToString(minFileSize),
                     compareAmount ? sizeToString(compareAmount) : "(unlimited)");
        }

        string[] dirs = args[1 .. $];

        if (dirs.length == 0) {
            help();
        }
        else {
            findDuplicates(dirs, minFileSize, compareAmount, verbose);
        }
    }
    catch (Exception ex) {
        writeln(ex.msg);
        exit(2);
    }

    return 0;
}

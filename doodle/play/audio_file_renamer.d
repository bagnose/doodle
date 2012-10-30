import std.stdio;
import std.path;
import std.string;
import std.file;
import std.regex;

enum Result {
    notMusic,
    goodMusic,
    fixableMusic,
    badMusic
}

Result checkPath(in string path, out string fixedPath) {
    string dir  = dirName(path);
    string file = baseName(path);

    if (auto a = match(path, r"\.(flac)$")) {
        string ext = a.captures[1];

        if (match(file, format(r"^([0-9]{2}) - (\S.*)\.%s$", ext))) {
            return Result.goodMusic;
        }

        // The contract here is that the jjjjj
        string[] patterns =
            [
            // David Bowie - Santa Monica '72/(18) - Rock 'N' Roll Suicide.flac
            format(r"^\(([0-9]{2})\) - (\S.*)\.%s$", ext),
            // The Beatles - Yesterday And Today (Dr. Ebbets Mono Butcher Cover)-1966/01. Drive My Car.flac
            format(r"^([0-9]{2})\. (\S.*)\.%s$", ext),
            // Ben Folds - Whatever and Ever Amen/12 Evaporated.flac
            r"^([0-9]{2}) (\S.*)\.(flac)$",
            // The Aliens - Luna (2008) [FLAC] {16bit-44kHz}/05-Magic-Man.flac
            r"^([0-9]{2})-(\S.*)\.(flac)$",
            // Beck - Midnight Vultures/05  Hollywood Freaks.flac
            r"^([0-9]{2})  (\S.*)\.(flac)$",
            // Chairlift - Does You Inspire You (2009 Re-issue) (2009)/10- Dixie Gypsy.flac
            r"^([0-9]{2})- (\S.*)\.(flac)$",
            // Captain Beefheart-The Spotlight Kid_Clear Spot/05Alice in Blunderland.flac
            r"^([0-9]{2})([a-zA-Z].*)\.(flac)$"
            ];

        foreach (p; patterns) {
            if (auto m = match(file, p)) {
                string track = m.captures[1];
                string title = m.captures[2];

                fixedPath = format("%s/%s - %s.%s", dir, track, title, ext);
                return Result.fixableMusic;
            }
        }

        return Result.badMusic;
    }
    else {
        return Result.notMusic;
    }
}

void traverse(in string dir) {
    foreach (entry; dirEntries(dir, SpanMode.shallow, false)) {
        if (isDir(entry)) {
            try {
                traverse(entry);
            }
            catch (FileException ex) {
                writefln("Error: %s", ex.msg);
            }
        }
        else if (isFile(entry)) {
            string fixedPath;

            final switch (checkPath(entry, fixedPath)) {
            case Result.notMusic:
                break;
            case Result.goodMusic:
                //writefln("Good %s", entry);
                break;
            case Result.fixableMusic:
                writefln("Fix %s\n--> %s", baseName(entry), baseName(fixedPath));
                break;
            case Result.badMusic:
                writefln("Bad %s", entry);
                break;
            }
        }
        else {
            // skip
        }
    }
}

void main(string args[]) {
    foreach(dir; args[1 .. $]) {
        if (isDir(dir)) {
            traverse(dir);
        }
        else {
            writefln("Not a directory %s", dir);
        }
    }
}

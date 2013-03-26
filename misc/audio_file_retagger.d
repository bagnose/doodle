
// http://www.blisshq.com/music-library-management-blog/2010/10/12/how-to-use-album_artist/

struct Info {
    string albumArtist;
    string albumTitle;
    string trackArtist;
    string year;
    string trackNum;
    string trackTitle;
}

bool getInfoFromPath(in string path, out Info info, bool nonStandardPath) {
    string dir  = dirName(path);
    string file = baseName(path);

    if (auto a = match(path, r"\.(flac)$")) {
        format(r"(([0-9]{2}) - (\S.*)\.%s$", ext))) {

        string ext = a.captures[1];
    }
    else {
        return false;
    }
}

/*
struct MultiInfo {
    Info fileInfo;
    Info tagInfo;
}
*/


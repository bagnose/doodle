import std.stdio;
import std.file;
import std.digest.md;

struct ByteAccumulator {
    alias ubyte[1] Hash;

    this(in string filename) {
        _file = File(filename);
    }

    bool accumulate(out Hash hash) {
        ubyte[1] buffer;
        ubyte[] slice = _file.rawRead(buffer);

        if (slice.length == 1) {
            hash = slice;
            return true;
        }
        else {
            hash[0] = 0;
            return false;
        }
    }

    private {
        File    _file;
    }
}

struct MD5Accumulator {
    alias ubyte[16] Hash;

    this(in string filename) {
        _file = File(filename);
        _buffer = new ubyte[64 * 1024];
    }

    bool accumulate(out Hash hash) {
        ubyte[] slice = _file.rawRead(_buffer);
        _md5.put(slice);
        hash = _md5.finish();
        return slice.length == _buffer.length;
    }

    private {
        File    _file;
        MD5     _md5;
        ubyte[] _buffer;
    }
}

int main(string[] args) {
    foreach (path; args[1 .. $]) {
        //auto ha = MD5Accumulator(path);
        auto ha = ByteAccumulator(path);
        for (;;) {
            ha.Hash hash;
            bool ongoing = ha.accumulate(hash);
            writefln(" %s", toHexString(hash));
            if (!ongoing) {
                break;
            }
        }
    }
    return 0;
}

import std.stdio;
import std.file;
import std.digest.md;

struct ByteAccumulator(size_t hashSize) {
    alias ubyte[hashSize] Hash;

    this(in string filename) {
        _file = File(filename);
    }

    void accumulate() {
        ubyte[] slice = _file.rawRead(_hash);

        if (slice.length == _hash.length) {
            _ongoing = true;
        }
        else {
            _hash[slice.length .. $] = 0;
            _ongoing = false;
        }
    }

    @property Hash hash()    const { return _hash; }
    @property bool ongoing() const { return _ongoing; }

    private {
        File    _file;
        Hash    _hash;
        bool    _ongoing;
    }
}

struct MD5Accumulator {
    alias ubyte[16] Hash;

    this(in string filename, size_t chunkSize = 64 * 1024) {
        _file = File(filename);
        _buffer = new ubyte[chunkSize];
    }

    void accumulate() {
        ubyte[] slice = _file.rawRead(_buffer);
        _md5.put(slice);
        _hash    = _md5.finish();
        _ongoing = slice.length == _buffer.length;
    }

    @property Hash hash()    const { return _hash; }
    @property bool ongoing() const { return _ongoing; }

    private {
        File    _file;
        MD5     _md5;
        ubyte[] _buffer;
        Hash    _hash;
        bool    _ongoing;
    }
}

int main(string[] args) {
    foreach (path; args[1 .. $]) {
        //auto ha = MD5Accumulator(path, 16);
        auto ha = ByteAccumulator!(16)(path);
        do {
            ha.accumulate();
            writefln(" %s", toHexString(ha.hash));
        } while (ha.ongoing);
    }
    return 0;
}

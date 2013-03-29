// vi:noai:sw=4

#ifndef BUFFER__HPP
#define BUFFER__HPP

#include "terminal/common.hpp"
#include "terminal/utf8.hpp"

#include <vector>
#include <iostream>
#include <cstdlib>

struct Glyph {
    char     ch[utf8::LMAX];
    uint8_t  mode;
    uint8_t  state;
    uint16_t fg;
    uint16_t bg;
};

//
//
//

struct Line {
    std::vector<Glyph> glyphs;
};

std::ostream & operator << (std::ostream & ost, const Line & line) {
    //ost << line._str;
    return ost;
}

// Circular buffer of lines. New lines are added to the end. Old lines
// are removed from the beginning when capacity is reached.
// When it's vertically shrunk you lose lines from the beginning.
class Buffer : protected Uncopyable {
    Line   * _data;
    size_t   _capacity;
    size_t   _offset;
    size_t   _size;

public:
    explicit Buffer(size_t capacity) :
        _data(reinterpret_cast<Line *>(std::malloc(capacity * sizeof(Line)))),
        _capacity(capacity),
        _offset(0),
        _size(0)
    {
        ASSERT(_data, "malloc() failed.");
    }

    ~Buffer() {
        for (size_t i = 0; i != _size; ++i) {
            Line * l = ptrNth(i);
            l->~Line();
        }
        std::free(_data);
    }

    // Add a line to the end of the buffer. If there is sufficient capacity
    // then grow the buffer. Otherwise replace the last line.
    void add(const Line & line) {
        Line * l = ptrNth(_size);
        if (_size == _capacity) {
            *l = line;
            ++_offset;
        }
        else {
            new (l) Line(line);
            ++_size;
        }
    }

    size_t getSize() const {
        return _size;
    }

    size_t getCapacity() const {
        return _capacity;
    }

    const Line & getNth(size_t index) const {
        ASSERT(index < _size, "Index out of range.");
        return *ptrNth(index);
    }

protected:
    const Line * ptrNth(size_t index) const {
        size_t rawIndex = ((_offset + index) % _capacity);
        return reinterpret_cast<const Line *>(&_data[rawIndex]);
    }

    Line * ptrNth(size_t index) {
        size_t rawIndex = ((_offset + index) % _capacity);
        return reinterpret_cast<Line *>(&_data[rawIndex]);
    }
};

void dumpBuffer(const Buffer & buffer) {
    std::cout << "Lines: " << buffer.getSize() << std::endl;
    for (size_t i = 0; i != buffer.getSize(); ++i) {
        std::cout << i << " " << buffer.getNth(i) << std::endl;
    }
}

#if 0
struct Viewport {
    uint16_t offset;      // offset from bottom of buffer
    uint16_t height;
};

struct Selection {
};
#endif

#endif // BUFFER__HPP

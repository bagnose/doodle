// vi:noai:sw=4

#ifndef BUFFER__HPP
#define BUFFER__HPP

#include "terminal/common.hpp"
#include "terminal/utf8.hpp"

#include <vector>
#include <deque>
#include <iostream>
#include <cstdlib>

struct Char {
    static Char ascii(char c) {
        Char ch;
        ch.bytes[0] = c;
        ch.bytes[1] = '\0';
        ch.bytes[2] = '\0';
        ch.bytes[3] = '\0';
        ch.mode  = 0;
        ch.state = 0;
        ch.fg    = 0;
        ch.bg    = 0;
        return ch;
    }

    static Char utf8(const char * s, utf8::Length length) {
        Char ch;
        std::copy(s, s + length, ch.bytes);
        ch.mode = 0;
        ch.state = 0;
        ch.fg    = 0;
        ch.bg    = 0;
        return ch;
    }

    char     bytes[utf8::LMAX];
    uint8_t  mode;
    uint8_t  state;
    uint16_t fg;
    uint16_t bg;
};

inline std::ostream & operator << (std::ostream & ost, const Char & ch) {
    utf8::Length l = utf8::leadLength(ch.bytes[0]);
    for (size_t i = 0; i != l; ++i) {
        ost << ch.bytes[i];
    }
    return ost;
}

//
//
//

class RawBuffer : protected Uncopyable {
    struct Line {
        std::vector<Char> chars;

        size_t size() const { return chars.size(); }

        void insert(const Char & ch, size_t col) {
            ASSERT(!(col > size()),);
            chars.insert(chars.begin() + col, ch);
        }
    };

    std::deque<Line> _lines;
    size_t           _sizeLimit;

public:
    RawBuffer(size_t size, size_t sizeLimit) :
        _lines(size, Line()),
        _sizeLimit(sizeLimit)
    {
        ASSERT(!(sizeLimit < size),);
    }

    size_t getSize() const { return _lines.size(); }

    uint16_t getWidth(size_t row) const {
        ASSERT(row < _lines.size(),);
        const Line & line = _lines[row];
        return line.size();
    }

    const Char & getChar(size_t row, uint16_t col) const {
        ASSERT(row < _lines.size(),);
        const Line & line = _lines[row];
        return line.chars[col];
    }

    bool addLine() {
        bool full = _lines.size() == _sizeLimit;
        if (full) _lines.pop_front();
        _lines.push_back(Line());
        return !full;
    }

    void insertChar(const Char & ch, size_t row, uint16_t col) {
        ASSERT(row < _lines.size(),);
        Line & line = _lines[row];
        ASSERT(!(col > line.chars.size()),);
        line.chars.insert(line.chars.begin() + col, ch);
    }
};

inline void dumpRawBuffer(const RawBuffer & buffer) {
    size_t rows = buffer.getSize();
    std::cout << "Lines: " << rows << std::endl;
    for (size_t r = 0; r != rows; ++r) {
        size_t cols = buffer.getWidth(r);
        std::cout << r << " ";
        for (size_t c = 0; c != cols; ++c) {
            std::cout << buffer.getChar(r, c);
        }
        std::cout << std::endl;
    }
}

//
//
//

class WrappedBuffer {
    struct Line {
        size_t   row;
        uint16_t colBegin;
        uint16_t colEnd;

        Line(size_t row_, uint16_t colBegin_, uint16_t colEnd_) :
            row(row_), colBegin(colBegin_), colEnd(colEnd_) {}

        uint16_t getWidth() const { return colEnd - colBegin; }
    };

    RawBuffer        _raw;
    std::deque<Line> _lines;
    size_t           _offset;
    uint16_t         _wrapCol;

public:
    WrappedBuffer(size_t wrapCol, size_t size, size_t sizeLimit) :
        _raw(size, sizeLimit),
        _lines(),
        _offset(0),
        _wrapCol(wrapCol)
    {
        ASSERT(!(sizeLimit < size),);

        for (size_t i = 0; i != size; ++i) {
            _lines.push_back(Line(i, 0, 0));
        }
    }

    size_t getSize() const { return _lines.size(); }

    uint16_t getWrapCol() const { return _wrapCol; }

    uint16_t getWidth(size_t row) const {
        ASSERT(row < _lines.size(),);
        const Line & line = _lines[row];
        return line.getWidth();
    }

    const Char & getChar(size_t row, uint16_t col) const {
        const Line & line = _lines[row];
        return _raw.getChar(line.row - _offset, line.colBegin + col);
    }

    void setWrapCol(uint16_t wrapCol) {
        if (_wrapCol == wrapCol) { return; }    // optimisation

        _lines.clear();
        _wrapCol = wrapCol;

        for (size_t row = 0; row != _raw.getSize(); ++row) {
            size_t width = _raw.getWidth(row);
            size_t col = 0;
            do {
                size_t colBegin = col;
                col += _wrapCol;
                size_t colEnd = std::min(col, width);
                _lines.push_back(Line(row, colBegin, colEnd));
            } while (col < width);
        }
    }

    bool addLine() {
        bool grew = _raw.addLine();

        if (!grew) {
            ASSERT(!_lines.empty(),);
            size_t row = _lines.front().row;
            do {
                _lines.pop_front();
            } while (!_lines.empty() && _lines.front().row == row);
            ++_offset;
        }

        _lines.push_back(Line(_raw.getSize() - 1, 0, 0));
    }

    void insertChar(const Char & ch, size_t row, uint16_t col) {
        ASSERT(row < _lines.size(),);
        Line & line = _lines[row];
        ASSERT(!(col > line.colEnd),);
        _raw.insertChar(ch, line.row - _offset, line.colBegin + col);
        ++line.colEnd;
        // TODO deal with wrapping
    }
};

inline void dumpWrappedBuffer(const WrappedBuffer & buffer) {
    size_t rows = buffer.getSize();
    std::cout << "Lines: " << rows << std::endl;
    for (size_t r = 0; r != rows; ++r) {
        size_t cols = buffer.getWidth(r);
        std::cout << r << " ";
        for (size_t c = 0; c != cols; ++c) {
            std::cout << buffer.getChar(r, c);
        }
        std::cout << std::endl;
    }
}

#endif // BUFFER__HPP

// vi:noai:sw=4

#ifndef SIMPLE_BUFFER__H
#define SIMPLE_BUFFER__H

#include "terminal/common.hpp"
#include "terminal/char.hpp"

#include <vector>
#include <deque>

class SimpleBuffer {
    class Line {
        std::vector<Char> _chars;

    public:
        explicit Line(uint16_t cols) : _chars(cols, Char::ascii(' ')) {}

        uint16_t getCols() const { return static_cast<uint16_t>(_chars.size()); }
        const Char & getChar(uint16_t col) const { return _chars[col]; }

        void insert(const Char & ch, uint16_t col) {
            ASSERT(col < getCols(),);
            _chars.insert(_chars.begin() + col, ch);
            _chars.pop_back();
        }

        void overwrite(const Char & ch, uint16_t col) {
            ASSERT(col < getCols(),);
            _chars[col] = ch;
        }

        void erase(uint16_t col) {
            ASSERT(col < getCols(),);
            _chars.erase(_chars.begin() + col);
            _chars.push_back(Char::ascii(' '));
        }
    };

    std::deque<Line> _lines;

public:
    SimpleBuffer(uint16_t rows, uint16_t cols) :
        _lines(rows, Line(cols))
    {
        ASSERT(rows != 0,);
        ASSERT(cols != 0,);
    }

    uint16_t getRows() const { return _lines.size(); }
    uint16_t getCols() const { return _lines.front().getCols(); }

    const Char & getChar(uint16_t row, uint16_t col) const {
        ASSERT(row < getRows(),);
        ASSERT(col < getCols(),);
        return _lines[row].getChar(col);
    }

    void insertChar(const Char & ch, uint16_t row, uint16_t col) {
        ASSERT(row < getRows(),);
        ASSERT(col < getCols(),);
        _lines[row].insert(ch, col);
    }

    void eraseChar(uint16_t row, uint16_t col) {
        ASSERT(row < getRows(),);
        ASSERT(col < getCols(),);
        _lines[row].erase(col);
    }

    void overwriteChar(const Char & ch, uint16_t row, uint16_t col) {
        ASSERT(row < getRows(),);
        ASSERT(col < getCols(),);
        _lines[row].overwrite(ch, col);
    }

    void resize(uint16_t rows, uint16_t cols) {
        _lines.clear();
        _lines.resize(rows, Line(cols));
    }

    void addLine() {
        _lines.push_back(Line(getCols()));
        _lines.pop_front();
    }

    void clear() {
        resize(getRows(), getCols());
    }

private:
};

#endif // SIMPLE_BUFFER__H


// vi:noai:sw=4

#ifndef CHAR__HPP
#define CHAR__HPP

#include "terminal/attributes.hpp"
#include "terminal/utf8.hpp"

#include <algorithm>

struct Char {
    static Char ascii(char c) {
        Char ch;
        ch.bytes[0] = c;
        ch.attributes.clear();
        ch.state    = 0;
        ch.fg       = 0;
        ch.bg       = 0;
        return ch;
    }

    static Char utf8(const char   * s,
                     utf8::Length   length,
                     AttributeSet   attributes,
                     uint8_t        state,
                     uint8_t        fg,
                     uint8_t        bg)
    {
        Char ch;
        std::copy(s, s + length, ch.bytes);
        ch.attributes  = attributes;
        ch.state       = state;
        ch.fg          = fg;
        ch.bg          = bg;
        return ch;
    }

    char         bytes[utf8::LMAX];
    AttributeSet attributes;
    uint8_t      state;
    uint8_t      fg;
    uint8_t      bg;
};

std::ostream & operator << (std::ostream & ost, const Char & ch);

#endif // CHAR__HPP

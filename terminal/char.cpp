// vi:noai:sw=4

#include "terminal/char.hpp"

#include <iostream>

std::ostream & operator << (std::ostream & ost, const Char & ch) {
    utf8::Length l = utf8::leadLength(ch.bytes[0]);
    for (size_t i = 0; i != l; ++i) {
        ost << ch.bytes[i];
    }
    return ost;
}

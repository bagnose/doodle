// vi:noai:sw=4

#include "terminal/char.hpp"

#include <iostream>

std::ostream & operator << (std::ostream & ost, const Char & ch) {
    ost << "'";
    utf8::Length l = utf8::leadLength(ch.bytes[0]);
    for (size_t i = 0; i != l; ++i) {
        ost << ch.bytes[i];
    }
    ost << "'";

    ost << ", attr="  << static_cast<int>(ch.attr)
        << ", state=" << static_cast<int>(ch.state)
        << ", fg="    << static_cast<int>(ch.fg)
        << ", bg="    << static_cast<int>(ch.bg);
    return ost;
}

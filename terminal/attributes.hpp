// vi:noai:sw=4

#ifndef ATTRIBUTES__H
#define ATTRIBUTES__H

#include <iosfwd>
#include <stdint.h>

enum Attr {
    ATTR_BOLD,
    ATTR_ITALIC,
    ATTR_UNDERLINE,
    ATTR_BLINK,
    ATTR_REVERSE
};

//
//
//

class AttrSet {
    uint8_t _bits;
    static uint8_t bit(Attr attr) { return 1 << attr; }

public:
    AttrSet() : _bits(0) {}

    void set(Attr attr)       { _bits |= bit(attr); }
    void unSet(Attr attr)     { _bits &= ~bit(attr); }
    bool get(Attr attr) const { return _bits & bit(attr); }
};

std::ostream & operator << (std::ostream & ost, AttrSet attrSet);

#endif // ATTRIBUTES__H

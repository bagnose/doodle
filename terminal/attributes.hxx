// vi:noai:sw=4

#ifndef ATTRIBUTES__H
#define ATTRIBUTES__H

#include <iosfwd>
#include <stdint.h>

enum Attribute {
    ATTRIBUTE_BOLD,
    ATTRIBUTE_ITALIC,
    ATTRIBUTE_UNDERLINE,
    ATTRIBUTE_BLINK,
    ATTRIBUTE_REVERSE
};

std::ostream & operator << (std::ostream & ost, Attribute    attribute);

//
//
//

class AttributeSet {
    uint8_t _bits;
    static uint8_t bit(Attribute attr) { return 1 << attr; }

public:
    AttributeSet() : _bits(0) {}

    void clear()                        { _bits  =  0;                   }
    void set(Attribute attribute)       { _bits |=  bit(attribute);      }
    void unSet(Attribute attribute)     { _bits &= ~bit(attribute);      }
    bool get(Attribute attribute) const { return _bits & bit(attribute); }
};

std::ostream & operator << (std::ostream & ost, AttributeSet attributeSet);

#endif // ATTRIBUTES__H

// vi:noai:sw=4

#ifndef BIT_SETS__HXX
#define BIT_SETS__HXX

#include "terminal/enums.hxx"

#include <iosfwd>
#include <stdint.h>

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

#endif // BIT_SETS__HXX

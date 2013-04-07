// vi:noai:sw=4

#include "terminal/attributes.hxx"
#include "terminal/common.hxx"

#include <iostream>

std::ostream & operator << (std::ostream & ost, Attribute attribute) {
    switch (attribute) {
        case ATTRIBUTE_BOLD:
            return ost << "BOLD";
        case ATTRIBUTE_ITALIC:
            return ost << "ITALIC";
        case ATTRIBUTE_UNDERLINE:
            return ost << "UNDERLINE";
        case ATTRIBUTE_BLINK:
            return ost << "BLINK";
        case ATTRIBUTE_REVERSE:
            return ost << "REVERSE";
    }

    FATAL(<<static_cast<int>(attribute));
}

std::ostream & operator << (std::ostream & ost, AttributeSet attributeSet) {
    return ost;
}

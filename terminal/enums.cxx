// vi:noai:sw=4

#include "terminal/enums.hxx"
#include "terminal/common.hxx"

std::ostream & operator << (std::ostream & ost, Control control) {
    switch (control) {
        case CONTROL_BEL:
            return ost << "BEL";
        case CONTROL_HT:
            return ost << "HT";
        case CONTROL_BS:
            return ost << "BS";
        case CONTROL_CR:
            return ost << "CR";
        case CONTROL_LF:
            return ost << "LF";
    }

    FATAL(<< static_cast<int>(control));
}

std::ostream & operator << (std::ostream & ost, ClearScreen clear) {
    switch (clear) {
        case CLEAR_SCREEN_BELOW:
            return ost << "BELOW";
        case CLEAR_SCREEN_ABOVE:
            return ost << "ABOVE";
        case CLEAR_SCREEN_ALL:
            return ost << "ALL";
    }

    FATAL(<< static_cast<int>(clear));
}

std::ostream & operator << (std::ostream & ost, ClearLine clear) {
    switch (clear) {
        case CLEAR_LINE_RIGHT:
            return ost << "RIGHT";
        case CLEAR_LINE_LEFT:
            return ost << "LEFT";
        case CLEAR_LINE_ALL:
            return ost << "ALL";
    }

    FATAL(<< static_cast<int>(clear));
}

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

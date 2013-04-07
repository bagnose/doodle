// vi:noai:sw=4

#ifndef X_FONT_SET__HPP
#define X_FONT_SET__HPP

#include "terminal/common.hpp"

#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>

class X_FontSet : protected Uncopyable {
    Display * mDisplay;
    XftFont * mNormal;
    XftFont * mBold;
    XftFont * mItalic;
    XftFont * mItalicBold;
    uint16_t  mWidth, mHeight;

public:
    X_FontSet(Display           * display,
              const std::string & fontName);

    ~X_FontSet();

    // Font accessors:

    XftFont * get(bool bold, bool italic) {
        switch ((bold ? 1 : 0) + (italic ? 2 : 0)) {
            case 0: return getNormal();
            case 1: return getBold();
            case 2: return getItalic();
            case 3: return getItalicBold();
        }
    }

    XftFont * getNormal()     { return mNormal; }
    XftFont * getBold()       { return mBold; }
    XftFont * getItalic()     { return mItalic; }
    XftFont * getItalicBold() { return mItalicBold; }

    // Misc:

    uint16_t getWidth()  const { return mWidth; }
    uint16_t getHeight() const { return mHeight; }

protected:
    XftFont * load(FcPattern * pattern);
    void      unload(XftFont * font);
};

#endif // X_FONT_SET__HPP

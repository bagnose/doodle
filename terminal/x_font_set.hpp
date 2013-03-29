// vi:noai:sw=4

#ifndef X_FONT_SET__HPP
#define X_FONT_SET__HPP

#include "terminal/common.hpp"

#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>

class X_FontSet : protected Uncopyable {
    Display * mDisplay;
    XftFont * mNormal;
    XftFont * mItalic;
    XftFont * mItalicBold;
    XftFont * mBold;
    uint16_t  mWidth, mHeight;

public:
    X_FontSet(Display           * display,
              const std::string & fontName);

    ~X_FontSet();

    // Font accessors:

    XftFont * normal()     { return mNormal; }
    XftFont * italic()     { return mItalic; }
    XftFont * italicBold() { return mItalicBold; }
    XftFont * bold()       { return mBold; }

    // Misc:

    uint16_t width()  const { return mWidth; }
    uint16_t height() const { return mHeight; }

protected:
    XftFont * load(FcPattern * pattern);
    void      unload(XftFont * font);
};

#endif // X_FONT_SET__HPP

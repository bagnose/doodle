// vi:noai:sw=4

#include "terminal/x_window.hpp"
#include "terminal/common.hpp"

#include <sstream>

#include <X11/Xutil.h>

const int X_Window::BORDER_THICKNESS    = 1;
const int X_Window::SCROLLBAR_WIDTH = 8;

X_Window::X_Window(Display            * display,
                   Screen             * screen,
                   X_FontSet          & fontSet,
                   const Tty::Command & command) :
    mDisplay(display),
    mScreen(screen),
    mFontSet(fontSet),
    mTerminal(nullptr)
{
    XSetWindowAttributes attributes;
    attributes.background_pixel = XBlackPixelOfScreen(mScreen);

    uint16_t cols = 80;
    uint16_t rows = 25;

    uint16_t width  = 2 * BORDER_THICKNESS + cols * mFontSet.width() + SCROLLBAR_WIDTH;
    uint16_t height = 2 * BORDER_THICKNESS + rows * mFontSet.height();

    mWindow = XCreateWindow(mDisplay,
                            XRootWindowOfScreen(mScreen),
                            0, 0,          // x,y
                            width, height, // w,h
                            0,             // border width
                            XDefaultDepthOfScreen(mScreen),
                            InputOutput,
                            XDefaultVisualOfScreen(mScreen),
                            CWBackPixel,
                            &attributes);

    XSetStandardProperties(mDisplay, mWindow,
                           "terminal", "terminal",
                           None, nullptr, 0, nullptr);

    XSelectInput(mDisplay, mWindow,
                 StructureNotifyMask | ExposureMask | ButtonPressMask | KeyPressMask);


    XMapWindow(mDisplay, mWindow);

    XFlush(mDisplay);

    mTerminal = new Terminal(*this, cols, rows, stringify(mWindow), "xterm", command);
}

X_Window::~X_Window() {
    delete mTerminal;

    XDestroyWindow(mDisplay, mWindow);
}

void X_Window::keyPress(XKeyEvent & event) {
    uint8_t  state   = event.state;
    uint16_t keycode = event.keycode;

    std::ostringstream maskStr;
    if (state & ShiftMask)   maskStr << " SHIFT";
    if (state & LockMask)    maskStr << " LOCK";
    if (state & ControlMask) maskStr << " CTRL";
    if (state & Mod1Mask)    maskStr << " ALT";
    if (state & Mod2Mask)    maskStr << " MOD2";
    if (state & Mod3Mask)    maskStr << " MOD3";
    if (state & Mod4Mask)    maskStr << " WIN";
    if (state & Mod5Mask)    maskStr << " MOD5";

    char   buffer[16];
    KeySym keysym;

    int len = XLookupString(&event, buffer, sizeof buffer, &keysym, nullptr);
    /*
    PRINT(<< "keycode=" << keycode << " mask=(" << maskStr.str() << ") " <<
          " str='" << std::string(buffer, buffer + len) << "'" << " len=" << len);
          */

    if (len > 0) {
        mTerminal->enqueue(buffer, len);
    }
}

void X_Window::keyRelease(XKeyEvent & event) {
}

void X_Window::buttonPress(XButtonEvent & event) {
}

void X_Window::buttonRelease(XButtonEvent & event) {
}

void X_Window::expose(XExposeEvent & event) {
    ASSERT(event.window == mWindow, "Which window?");
    PRINT("Expose: " <<
          event.x << " " << event.y << " " <<
          event.width << " " << event.height);

    if (event.count == 0) {
        //draw(event.x, event.y, event.width, event.height);
        draw(0, 0, mWidth, mHeight);
    }
}

void X_Window::configure(XConfigureEvent & event) {
    ASSERT(event.window == mWindow, "Which window?");
    PRINT("Configure notify: " <<
          event.x << " " << event.y << " " <<
          event.width << " " << event.height);

    mWidth  = event.width;
    mHeight = event.height;

    uint16_t cols, rows;

    if (mWidth  > 2 * BORDER_THICKNESS + mFontSet.width() + SCROLLBAR_WIDTH &&
        mHeight > 2 * BORDER_THICKNESS + mFontSet.height() )
    {
        uint16_t w = mWidth  - (2 * BORDER_THICKNESS + SCROLLBAR_WIDTH);
        uint16_t h = mHeight - (2 * BORDER_THICKNESS);

        cols = w / mFontSet.width();
        rows = h / mFontSet.height();
    }
    else {
        rows = cols = 1;
    }

    ASSERT(rows > 0 && cols > 0,);

    mTerminal->resize(cols, rows);

    draw(0, 0, mWidth, mHeight);
}

void X_Window::draw(uint16_t ix, uint16_t iy, uint16_t iw, uint16_t ih) {
    XClearWindow(mDisplay, mWindow);

    XftDraw * xftDraw = XftDrawCreate(mDisplay, mWindow,
                                      XDefaultVisualOfScreen(mScreen),
                                      XDefaultColormapOfScreen(mScreen));

    XRenderColor xrColor;
    XftColor     xftColor;
    xrColor.red   = 0x7777;
    xrColor.green = 0xaaaa;
    xrColor.blue  = 0xffff;
    xrColor.alpha = 0xffff;
    XftColorAllocValue(mDisplay,
                       XDefaultVisualOfScreen(mScreen),
                       XDefaultColormapOfScreen(mScreen),
                       &xrColor, &xftColor);

    int y = -1;

    for (size_t r = 0; r != mTerminal->buffer().getSize(); ++r) {
        int x = 1;
        y += mFontSet.height() + 1;

        for (size_t c = 0; c != mTerminal->buffer().getWidth(r); ++c) {
            const Char & ch = mTerminal->buffer().getChar(r, c);
            XftDrawStringUtf8(xftDraw, &xftColor,
                              mFontSet.normal(), x, y,
                              (const FcChar8 *)ch.bytes, utf8::leadLength(ch.bytes[0]));
            x += mFontSet.width();
        }
    }

    XftColorFree(mDisplay, XDefaultVisualOfScreen(mScreen),
                 XDefaultColormapOfScreen(mScreen),
                 &xftColor);

    XftDrawDestroy(xftDraw);

    XFlush(mDisplay);
}

// Buffer::IObserver implementation:

void X_Window::terminalBegin() throw () {
}

void X_Window::damageAll() throw () {
}

void X_Window::terminalEnd() throw () {
    draw(0, 0, mWidth, mHeight);
}

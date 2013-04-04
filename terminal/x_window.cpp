// vi:noai:sw=4

#include "terminal/x_window.hpp"
#include "terminal/common.hpp"

#include <sstream>

#include <X11/Xutil.h>

const int X_Window::BORDER_THICKNESS = 1;
const int X_Window::SCROLLBAR_WIDTH  = 8;

X_Window::X_Window(Display            * display,
                   Screen             * screen,
                   X_FontSet          & fontSet,
                   const Tty::Command & command) :
    _display(display),
    _screen(screen),
    _fontSet(fontSet),
    _terminal(nullptr)
{
    XSetWindowAttributes attributes;
    attributes.background_pixel = XBlackPixelOfScreen(_screen);

    uint16_t cols = 80;
    uint16_t rows = 25;

    uint16_t width  = 2 * BORDER_THICKNESS + cols * _fontSet.width() + SCROLLBAR_WIDTH;
    uint16_t height = 2 * BORDER_THICKNESS + rows * _fontSet.height();

    _window = XCreateWindow(_display,
                            XRootWindowOfScreen(_screen),
                            0, 0,          // x,y
                            width, height, // w,h
                            0,             // border width
                            XDefaultDepthOfScreen(_screen),
                            InputOutput,
                            XDefaultVisualOfScreen(_screen),
                            CWBackPixel,
                            &attributes);

    XSetStandardProperties(_display, _window,
                           "terminal", "terminal",
                           None, nullptr, 0, nullptr);

    XSelectInput(_display, _window,
                 StructureNotifyMask | ExposureMask | ButtonPressMask | KeyPressMask);


    XMapWindow(_display, _window);

    XFlush(_display);

    _terminal = new Terminal(*this, cols, rows, stringify(_window), "xterm", command);
}

X_Window::~X_Window() {
    delete _terminal;

    XDestroyWindow(_display, _window);
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
        _terminal->enqueue(buffer, len);
    }
}

void X_Window::keyRelease(XKeyEvent & event) {
}

void X_Window::buttonPress(XButtonEvent & event) {
}

void X_Window::buttonRelease(XButtonEvent & event) {
}

void X_Window::expose(XExposeEvent & event) {
    ASSERT(event.window == _window, "Which window?");
    /*
       PRINT("Expose: " <<
       event.x << " " << event.y << " " <<
       event.width << " " << event.height);
       */

    if (event.count == 0) {
        //draw(event.x, event.y, event.width, event.height);
        draw(0, 0, _width, _height);
    }
}

void X_Window::configure(XConfigureEvent & event) {
    ASSERT(event.window == _window, "Which window?");
    /*
       PRINT("Configure notify: " <<
       event.x << " " << event.y << " " <<
       event.width << " " << event.height);
       */

    _width  = event.width;
    _height = event.height;

    uint16_t cols, rows;

    if (_width  > 2 * BORDER_THICKNESS + _fontSet.width() + SCROLLBAR_WIDTH &&
        _height > 2 * BORDER_THICKNESS + _fontSet.height())
    {
        uint16_t w = _width  - (2 * BORDER_THICKNESS + SCROLLBAR_WIDTH);
        uint16_t h = _height - (2 * BORDER_THICKNESS);

        cols = w / _fontSet.width();
        rows = h / _fontSet.height();
    }
    else {
        rows = cols = 1;
    }

    ASSERT(rows > 0 && cols > 0,);

    _terminal->resize(cols, rows);

    draw(0, 0, _width, _height);
}

void X_Window::rowCol2XY(uint16_t col, size_t row,
                       uint16_t & x, uint16_t & y) const {
    x = BORDER_THICKNESS + col * _fontSet.width();
    y = BORDER_THICKNESS + (row + 1) * _fontSet.height();
}

void X_Window::draw(uint16_t ix, uint16_t iy, uint16_t iw, uint16_t ih) {
    XClearWindow(_display, _window);

    XftDraw * xftDraw = XftDrawCreate(_display, _window,
                                      XDefaultVisualOfScreen(_screen),
                                      XDefaultColormapOfScreen(_screen));

    XRenderColor xrColor;
    XftColor     xftColor;

    xrColor.red   = 0x7777;
    xrColor.green = 0xaaaa;
    xrColor.blue  = 0xffff;
    xrColor.alpha = 0xffff;
    XftColorAllocValue(_display,
                       XDefaultVisualOfScreen(_screen),
                       XDefaultColormapOfScreen(_screen),
                       &xrColor, &xftColor);

    for (size_t r = 0; r != _terminal->buffer().getSize(); ++r) {
        for (size_t c = 0; c != _terminal->buffer().getWidth(r); ++c) {
            uint16_t x, y;
            rowCol2XY(c, r, x, y);

            const Char & ch = _terminal->buffer().getChar(r, c);
            XftDrawStringUtf8(xftDraw, &xftColor,
                              _fontSet.normal(), x, y,
                              (const FcChar8 *)ch.bytes, utf8::leadLength(ch.bytes[0]));
            x += _fontSet.width();
        }
    }

    XftColorFree(_display, XDefaultVisualOfScreen(_screen),
                 XDefaultColormapOfScreen(_screen),
                 &xftColor);

#if 1
    xrColor.red   = 0xffff;
    xrColor.green = 0xaaaa;
    xrColor.blue  = 0xaaaa;
    xrColor.alpha = 0xffff;
    XftColorAllocValue(_display,
                       XDefaultVisualOfScreen(_screen),
                       XDefaultColormapOfScreen(_screen),
                       &xrColor, &xftColor);

    {
        uint16_t x, y;
        rowCol2XY(_terminal->cursorCol(), _terminal->cursorRow(), x, y);
        XftDrawStringUtf8(xftDraw, &xftColor,
                          _fontSet.normal(), x, y,
                          (const FcChar8 *)"¶", 2);
    }

    XftColorFree(_display, XDefaultVisualOfScreen(_screen),
                 XDefaultColormapOfScreen(_screen),
                 &xftColor);
#endif

    XftDrawDestroy(xftDraw);

    XFlush(_display);
}

// Buffer::IObserver implementation:

void X_Window::terminalBegin() throw () {
}

void X_Window::damageAll() throw () {
}

void X_Window::terminalEnd() throw () {
    draw(0, 0, _width, _height);
}

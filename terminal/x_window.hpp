// vi:noai:sw=4

#ifndef X_WINDOW__HPP
#define X_WINDOW__HPP

#include "terminal/common.hpp"
#include "terminal/terminal.hpp"
#include "terminal/x_color_set.hpp"
#include "terminal/x_font_set.hpp"

#include <vector>
#include <string>

#include <X11/Xlib.h>

class X_Window :
    protected Terminal::IObserver,
    protected Uncopyable
{
    static const int BORDER_THICKNESS;
    static const int SCROLLBAR_WIDTH;

    Display    * _display;
    Screen     * _screen;
    X_ColorSet & _colorSet;
    X_FontSet  & _fontSet;
    bool         _damage;
    Window       _window;
    uint16_t     _width;     // px
    uint16_t     _height;    // px
    Terminal   * _terminal;

public:
    X_Window(Display            * display,
             Screen             * screen,
             X_ColorSet         & colorSet,
             X_FontSet          & fontSet,
             const Tty::Command & command);

    virtual ~X_Window();

    // The following calls are forwarded to the Terminal.

    bool isOpen() const { return _terminal->isOpen(); }
    int getFd() { return _terminal->getFd(); }
    void read() { _terminal->read(); }
    bool isQueueEmpty() const { return _terminal->isQueueEmpty(); }
    void write() { _terminal->write(); }

    // Events:

    void keyPress(XKeyEvent & event);
    void keyRelease(XKeyEvent & event);
    void buttonPress(XButtonEvent & event);
    void buttonRelease(XButtonEvent & event);
    void expose(XExposeEvent & event);
    void configure(XConfigureEvent & event);

protected:
    void rowCol2XY(uint16_t col, size_t row, uint16_t & x, uint16_t & y) const;

    void draw(uint16_t ix, uint16_t iy, uint16_t iw, uint16_t ih);

    // Buffer::IObserver implementation:

    void terminalBegin() throw ();
    void damageAll() throw ();
    void terminalEnd() throw ();
};

#endif // X_WINDOW__HPP

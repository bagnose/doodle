// vi:noai:sw=4

#ifndef X_WINDOW__HPP
#define X_WINDOW__HPP

#include "terminal/common.hpp"
#include "terminal/terminal.hpp"
#include "terminal/x_font_set.hpp"

#include <vector>
#include <string>

#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>

class X_Window :
    protected Terminal::IObserver,
    protected Uncopyable
{
    static const int BORDER_THICKNESS;
    static const int SCROLLBAR_WIDTH;

    Terminal    mTerminal;
    Display   * mDisplay;
    Screen    * mScreen;
    X_FontSet & mFontSet;
    Window      mWindow;
    uint16_t    mWidth;
    uint16_t    mHeight;

public:
    X_Window(Display            * display,
             Screen             * screen,
             X_FontSet          & fontSet,
             const Tty::Command & command);

    virtual ~X_Window();

    // The following calls are forwarded to the Terminal.

    bool isOpen() const { return mTerminal.isOpen(); }
    int getFd() { return mTerminal.getFd(); }
    void read() { mTerminal.read(); }
    bool isQueueEmpty() const { return mTerminal.isQueueEmpty(); }
    void write() { mTerminal.write(); }

    // Events:

    void keyPress(XKeyEvent & event);
    void keyRelease(XKeyEvent & event);
    void buttonPress(XButtonEvent & event);
    void buttonRelease(XButtonEvent & event);
    void expose(XExposeEvent & event);
    void configure(XConfigureEvent & event);

protected:
    void draw(uint16_t ix, uint16_t iy, uint16_t iw, uint16_t ih);

    // Buffer::IObserver implementation:

    void terminalBegin() throw ();
    void damageAll() throw ();
    void terminalEnd() throw ();
};

#endif // X_WINDOW__HPP

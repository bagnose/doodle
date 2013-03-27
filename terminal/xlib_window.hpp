// vi:noai:sw=4

#ifndef WINDOW__H
#define WINDOW__H

#include "terminal/tty.hpp"

#include <vector>

namespace X11 {
#include <X11/Xlib.h>
} // namespace X11

class Window : protected Tty::IObserver {
    X11::Display * mDisplay;
    X11::Window    mWindow;
    Tty            mTty;
    uint16_t       mWidth;
    uint16_t       mHeight;

    // XXX remove all this stuff:
    typedef std::vector<std::string> Text;
    Text mText;

public:
    Window(X11::Display * display,
           X11::Screen  * screen) :
        mDisplay(display),
        mTty(*this),
        mText(1, std::string())
    {
        X11::XSetWindowAttributes attributes;
        attributes.background_pixel = X11::XBlackPixelOfScreen(screen);

        mWindow = X11::XCreateWindow(display,
                                     X11::XRootWindowOfScreen(screen),
                                     0, 0,          // x,y
                                     320, 240,      // w,h
                                     0,             // border width
                                     X11::XDefaultDepthOfScreen(screen),
                                     InputOutput,
                                     X11::XDefaultVisualOfScreen(screen),
                                     CWBackPixel,
                                     &attributes);

        X11::XSelectInput(mDisplay, mWindow, ExposureMask | ButtonPressMask | KeyPressMask);


        X11::XMapWindow(mDisplay, mWindow);

        X11::XFlush(mDisplay);

        mTty.open(80, 24, "1234", "blah-term");
    }

    virtual ~Window() {
        X11::XDestroyWindow(mDisplay, mWindow);
    }

    bool isOpen() const {
        return mTty.isOpen();
    }

    int getFd() {
        ASSERT(isOpen(),);
        return mTty.getFd();
    }

    void read() {
        mTty.read();
    }

    bool queueEmpty() const {
        return mTty.queueEmpty();
    }

    void write() {
        mTty.write();
    }

    // Events:

    void keyPress(const X11::XKeyEvent & event) {
        /*
        bool shft = event.state & ShiftMask;
        bool ctrl = event.state & ControlMask;
        bool meta = event.state & ModMetaMask;
        */
    }

    void keyRelease(const X11::XKeyEvent & event) {
    }

    void buttonPress(const X11::XButtonEvent & event) {
    }

    void buttonRelease(const X11::XButtonEvent & event) {
    }

    void expose(const X11::XExposeEvent & event) {
        ASSERT(event.window == mWindow, "Which window?");
        PRINT("Expose: " <<
              event.x << " " << event.y << " " <<
              event.width << " " << event.height);

        draw(event.x, event.y, event.width, event.height);
    }

    void configure(const X11::XConfigureEvent & event) {
        ASSERT(event.window == mWindow, "Which window?");
        PRINT("Configure notify: " <<
              event.x << " " << event.y << " " <<
              event.width << " " << event.height);

        mWidth  = event.width;
        mHeight = event.height;

        draw(0, 0, mWidth, mHeight);
    }

protected:
    void draw(uint16_t ix, uint16_t iy, uint16_t iw, uint16_t ih) {

    }

    // Tty::IObserver implementation:

    void readResults(const char * data, size_t length) throw () {
        for (size_t i = 0; i != length; ++i) {
          char c = data[i];
            if (isascii(c)) {
                //PRINT("Got ascii: " << int(c) << ": " << c);

                // XXX total stupid hackery.
                if (c == '\n') {
                  mText.push_back(std::string());
                }
                else if (c == '\b') {
                  if (!mText.back().empty()) {
                    mText.back().pop_back();
                  }
                }
                else {
                  mText.back().push_back(c);
                }

                draw(0, 0, mWidth, mHeight);
            }
            else {
                //PRINT("Got other: " << int(c));
            }
        }
    }

    void childExited(int exitStatus) throw () {
        PRINT("Child exited: " << exitStatus);
    }
};

#endif // WINDOW__H

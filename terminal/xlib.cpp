// vi:noai:sw=4

#include "terminal/common.hpp"

#include "terminal/xlib_window.hpp"

namespace X11 {
#include <X11/Xlib.h>
} // namespace X11

class SimpleEventLoop {
    X11::Display * mDisplay;
    X11::Screen  * mScreen;
    Window       * mWindow;
public:
    SimpleEventLoop() {
        mDisplay = X11::XOpenDisplay(nullptr);
        ENFORCE(mDisplay, "Failed to open display.");
        mScreen = X11::XDefaultScreenOfDisplay(mDisplay);

        mWindow = new Window(mDisplay, mScreen);

        loop();
    }

    ~SimpleEventLoop() {
        delete mWindow;
        X11::XCloseDisplay(mDisplay);
    }

protected:
    void loop() {
        while (mWindow->isOpen()) {
            int fdMax = 0;
            fd_set readFds, writeFds;
            FD_ZERO(&readFds); FD_ZERO(&writeFds);

            FD_SET(X11::XConnectionNumber(mDisplay), &readFds);
            fdMax = std::max(fdMax, X11::XConnectionNumber(mDisplay));

            FD_SET(mWindow->getFd(), &readFds);
            fdMax = std::max(fdMax, mWindow->getFd());

            if (!mWindow->queueEmpty()) {
                FD_SET(mWindow->getFd(), &writeFds);
                fdMax = std::max(fdMax, mWindow->getFd());
            }

            ENFORCE_SYS(::select(fdMax + 1, &readFds, nullptr, nullptr, nullptr) != -1, "");

            if (FD_ISSET(X11::XConnectionNumber(mDisplay), &readFds)) {
                //PRINT("xevent");
                xevent();
            }

            if (FD_ISSET(mWindow->getFd(), &readFds)) {
                //PRINT("window read event");
                mWindow->read();
                if (!mWindow->isOpen()) {
                    break;
                }
            }

            if (!mWindow->queueEmpty()) {
                if (FD_ISSET(mWindow->getFd(), &writeFds)) {
                    //PRINT("window write event");
                    mWindow->write();
                }
            }
        }
    }

    void xevent() {
        X11::XEvent event;
        PRINT(<< X11::XNextEvent(mDisplay, &event));

        switch (event.type) {
            case KeyPress:
                mWindow->keyPress(event.xkey);
                break;
            case KeyRelease:
                mWindow->keyRelease(event.xkey);
                break;
            case ButtonPress:
                mWindow->buttonPress(event.xbutton);
                break;
            case ButtonRelease:
                mWindow->buttonRelease(event.xbutton);
                break;
            case Expose:
                mWindow->expose(event.xexpose);
                break;
            case ConfigureNotify:
                mWindow->configure(event.xconfigure);
                break;
            default:
                PRINT("Unrecognised event: " << event.type);
                break;
        }
    }
};

int main() {
    SimpleEventLoop eventLoop;

    return 0;
}

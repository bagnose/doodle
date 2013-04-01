// vi:noai:sw=4

#include "terminal/common.hpp"
#include "terminal/x_window.hpp"
#include "terminal/x_font_set.hpp"

#include <string>

#include <fontconfig/fontconfig.h>

#include <X11/Xlib.h>

class SimpleEventLoop : protected Uncopyable {
    Display  * mDisplay;
    X_Window * mWindow;
public:
    SimpleEventLoop(Display            * display,
                    Screen             * screen,
                    X_FontSet          & fontSet,
                    const Tty::Command & command) :
        mDisplay(display),
        mWindow(new X_Window(mDisplay, screen, fontSet, command))
    {
        loop();
    }

    ~SimpleEventLoop() {
        delete mWindow;
    }

protected:
    void loop() {
        while (mWindow->isOpen()) {
            int fdMax = 0;
            fd_set readFds, writeFds;
            FD_ZERO(&readFds); FD_ZERO(&writeFds);

            FD_SET(XConnectionNumber(mDisplay), &readFds);
            fdMax = std::max(fdMax, XConnectionNumber(mDisplay));

            FD_SET(mWindow->getFd(), &readFds);
            fdMax = std::max(fdMax, mWindow->getFd());

            bool selectOnWrite = !mWindow->isQueueEmpty();
            if (selectOnWrite) {
                FD_SET(mWindow->getFd(), &writeFds);
                fdMax = std::max(fdMax, mWindow->getFd());
            }

            ENFORCE_SYS(::select(fdMax + 1, &readFds, &writeFds, nullptr,
                                 nullptr) != -1,);

            // Handle _one_ I/O.

            if (FD_ISSET(XConnectionNumber(mDisplay), &readFds)) {
                //PRINT("xevent");
                xevent();
            }
            else if (FD_ISSET(mWindow->getFd(), &readFds)) {
                //PRINT("window read event");
                mWindow->read();
            }
            else if (selectOnWrite && FD_ISSET(mWindow->getFd(), &writeFds)) {
                //PRINT("window write event");
                mWindow->write();
            }
        }
    }

    void xevent() {
        while (XPending(mDisplay) != 0) {
            XEvent event;
            XNextEvent(mDisplay, &event);

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
    }
};

//
//
//

bool argMatch(const std::string & arg, const std::string & opt, std::string & val) {
    std::string optComposed = "--" + opt + "=";
    if (arg.substr(0, optComposed.size()) ==  optComposed) {
        val = arg.substr(optComposed.size());
        return true;
    }
    else {
        return false;
    }
}

int main(int argc, char * argv[]) {
    // Steps:
    // - parse cmd-line args
    // - convert font string to fc-pattern
    // - open display
    // - load font
    // - open socket
    // - event loop
    // -   socket read
    // -   socket write
    // -   window
    // -   master read
    // -   master write

    std::string fontName = "inconsolata:pixelsize=16"; 
    std::string geometryStr;
    Tty::Command command;
    bool accumulateCommand = false;

    for (int i = 1; i != argc; ++i) {
        std::string arg = argv[i];
        if (accumulateCommand) { command.push_back(arg); }
        else if (arg == "--execute") { accumulateCommand = true; }
        else if (argMatch(arg, "font", fontName)) { }
        else if (argMatch(arg, "geometry", geometryStr)) {}
        else { FATAL("Unrecognised argument: " << arg); }
    }

    if (!geometryStr.empty()) {
        int          x, y;
        unsigned int w, h;
        int bits = XParseGeometry(geometryStr.c_str(), &x, &y, &w, &h);

        if (bits & XValue) ;
        if (bits & YValue) ;
        if (bits & XNegative) ;
        if (bits & YNegative) ;
        if (bits & WidthValue) ;
        if (bits & HeightValue) ;
    }

    FcInit();

    Display * display = XOpenDisplay(nullptr);
    ENFORCE(display, "Failed to open display.");
    Screen * screen = XDefaultScreenOfDisplay(display);
    ASSERT(screen,);

    X_FontSet fontSet(display, fontName);

    SimpleEventLoop eventLoop(display, screen, fontSet, command);

    XCloseDisplay(display);

    // XXX The following causes an assertion failure.
    //FcFini();

    return 0;
}
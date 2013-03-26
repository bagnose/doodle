// vi:noai:sw=4

#include <string>
#include <deque>
#include <sstream>
#include <map>

#include <cstdlib>
#include <cstdio>

#include <stdint.h>
#include <pty.h>
#include <signal.h>
#include <unistd.h>
#include <pwd.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/types.h>
#include <sys/wait.h>

#include <xcb/xcb.h>
#include <xcb/xcb_event.h>
#include <xcb/xcb_keysyms.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include <freetype/freetype.h>

#include <cairo-xcb.h>
#include <cairo-ft.h>

#include "terminal/common.hpp"

// Control code: ascii 0-31, e.g. BS/backspace, CR/carriage-return, etc
// Escape sequence: ESC followed by a series of 'ordinary' characters.
//                  e.g. echo -e '\033[0;32mBLUE'
//                       echo -e '\033[5B' (move the cursor down 5 lines)

// TODO
// Maybe we should call waitpid() when the read() fails?
// What about the write() failing? EPIPE?

// Ways we can tell the child has exited:
//  - read error on pty
//  - write error on pty
//  - SIGCHLD
//  
//  Maybe, wait for read/write error and do a waitpid() ??

class Tty {
public:
    class IObserver {
    public:
        virtual void readResults(const char * data, size_t length) throw () = 0;
        virtual void childExited(int exitStatus) throw () = 0;

    protected:
        IObserver() throw () {}
        ~IObserver() throw () {}
    };

private:
    IObserver         & mObserver;
    bool                mOpen;
    uint16_t            mRows, mColumns;
    int                 mFd;
    pid_t               mPid;
    bool                mChildExited;
    bool                mChildExitCode;
    std::deque<char>    mWriteBuffer;

    // Status stuff:

    typedef std::map<pid_t, Tty *> PidTtyMap;

    static bool         mHandlerInstalled;
    static sighandler_t mOldHandler;
    static PidTtyMap    mPidTtyMap;

public:
    explicit Tty(IObserver & observer) :
        mObserver(observer),
        mOpen(false),
        mRows(0),
        mColumns(0),
        mFd(-1),
        mPid(0),
        mChildExited(false),
        mChildExitCode(0)
    {
        ASSERT(mHandlerInstalled, "Handler must be installed.");
    }

    ~Tty() {
        if (mOpen) {
            ENFORCE_SYS(::close(mFd) != -1,);
            mPidTtyMap.erase(mPidTtyMap.find(mPid));
        }
    }

    static void installHandler() {
        ASSERT(!mHandlerInstalled, "Handler already installed.");
        mOldHandler = ::signal(SIGCHLD, &signalHandler);
        mHandlerInstalled = true;
    }

    static void uninstallHandler() {
        ASSERT(mHandlerInstalled, "Handler not installed.");
        ::signal(SIGCHLD, mOldHandler);
        mHandlerInstalled = false;
    }

    void open(uint16_t            rows,
              uint16_t            columns,
              const std::string & windowId,
              const std::string & term) {
        mRows    = rows;
        mColumns = columns;
        openPty(windowId, term);
        mOpen    = true;
    }

    // Only select on the fd, no read/write.
    int getFd() {
        ASSERT(mOpen, "Not open.");
        return mFd;
    }

    void read() {
        ASSERT(mOpen, "Not open.");
        char buffer[1024];

        ssize_t rval = ::read(mFd, static_cast<void *>(buffer), sizeof buffer);

        if (rval == -1) {
            ASSERT(mChildExited, "Child hasn't exited.");

            // XXX This seems to happen when the child terminates. I'm surprised
            // we don't get an EOF.
            ENFORCE_SYS(::close(mFd) != -1,);
            mPidTtyMap.erase(mPidTtyMap.find(mPid));
            mPid  = 0;
            mOpen = false;

            mObserver.childExited(mChildExitCode);
        }
        else if (rval == 0) {
            ASSERT(false, "EOF!");
        }
        else {
            mObserver.readResults(buffer, static_cast<size_t>(rval));
        }
    }

    bool queueEmpty() const {
        ASSERT(mOpen, "Not open.");
        return mWriteBuffer.empty();
    }

    void enqueue(const char * data, size_t size) {
        ASSERT(mOpen, "Not open.");
#if 0
        for (const char * d = data; size != 0; --size)
        {
            mWriteBuffer.push_back(*d);
        }
#else
        size_t oldSize = mWriteBuffer.size();
        mWriteBuffer.resize(oldSize + size);
        std::copy(data, data + size, &mWriteBuffer[oldSize]);
#endif
    }

    void write() {
        ASSERT(mOpen, "Not open.");
        ASSERT(!queueEmpty(), "No writes queued");

        ssize_t rval = ::write(mFd, static_cast<const void *>(&mWriteBuffer.front()),
                               mWriteBuffer.size());

        if (rval == -1) {
            // XXX experimentation revealed that we get here if the
            // child exits and there is data in the queue.
            ASSERT(false, "::write() failed.");
        }
        else if (rval == 0) {
            ASSERT(false, "::write() zero bytes!");
        }
        else {
            mWriteBuffer.erase(mWriteBuffer.begin(), mWriteBuffer.begin() + rval);
        }
    }

protected:
    void openPty(const std::string & windowId,
                 const std::string & term) {
        int master, slave;
        struct winsize winsize = { mColumns, mRows, 0, 0 };

        ENFORCE_SYS(::openpty(&master, &slave, nullptr, nullptr, &winsize) != -1,);

        pid_t pid = ::fork();
        ENFORCE_SYS(pid != -1, "::fork() failed.");

        if (pid != 0) {
            // Parent code-path.

            ENFORCE_SYS(::close(slave) != -1,);

            // Stash the useful bits.
            mFd  = master;
            mPid = pid;
            mPidTtyMap[mPid] = this;
        }
        else {
            // Child code-path.

            // Create a new process group.
            ENFORCE_SYS(::setsid() != -1, "");
            // Hook stdin/out/err up to the PTY.
            ENFORCE_SYS(::dup2(slave, STDIN_FILENO)  != -1,);
            ENFORCE_SYS(::dup2(slave, STDOUT_FILENO) != -1,);
            ENFORCE_SYS(::dup2(slave, STDERR_FILENO) != -1,);
            ENFORCE_SYS(::ioctl(slave, TIOCSCTTY, nullptr) != -1,);
            ENFORCE_SYS(::close(slave) != -1, "");
            ENFORCE_SYS(::close(master) != -1,);
            execShell(windowId, term);
        }
    }

    // Called from the fork child.
    void execShell(const std::string & windowId,
                   const std::string & term) {
        ::unsetenv("COLUMNS");
        ::unsetenv("LINES");
        ::unsetenv("TERMCAP");

        const struct passwd * passwd = ::getpwuid(::getuid());
        if (passwd) {
            ::setenv("LOGNAME", passwd->pw_name,  1);
            ::setenv("USER",    passwd->pw_name,  1);
            ::setenv("SHELL",   passwd->pw_shell, 0);
            ::setenv("HOME",    passwd->pw_dir,   0);
        }

        ::setenv("WINDOWID", windowId.c_str(), 1);

        ::signal(SIGCHLD, SIG_DFL);
        ::signal(SIGHUP,  SIG_DFL);
        ::signal(SIGINT,  SIG_DFL);
        ::signal(SIGQUIT, SIG_DFL);
        ::signal(SIGTERM, SIG_DFL);
        ::signal(SIGALRM, SIG_DFL);

        const char * envShell = std::getenv("SHELL");
        if (!envShell) {
            envShell = "/bin/sh";
        }
        ::setenv("TERM", term.c_str(), 1);

        const char * const args[] = { envShell, "-i", nullptr };
        ::execvp(args[0], const_cast<char * const *>(args));
        // We only get here if the exec call failed.
        ERROR("Failed to launch: " << envShell);
    }

    static void signalHandler(int sigNum) {
        ASSERT(sigNum == SIGCHLD, "Unexpeted signal: " << ::strsignal(sigNum));

        int stat = 0;
        pid_t pid = ::wait(&stat);
        ENFORCE_SYS(pid != -1, "::wait failed.");

        // Map the pid back to the Tty and invoke the instance method.
        PidTtyMap::const_iterator iter = mPidTtyMap.find(pid);

        if (iter == mPidTtyMap.end()) {
            // This can happen if the Tty object was destroyed before
            // the child.
        }
        else {
            Tty * tty = iter->second;
            ASSERT(tty, "Null tty.");
            tty->childExited(stat);
        }
    }

    void childExited(int stat) {
        if (WIFEXITED(stat)) {
            mChildExitCode = WEXITSTATUS(stat);
        }
        else {
            mChildExitCode = EXIT_FAILURE;
        }

        mChildExited = true;
    }
};

bool Tty::mHandlerInstalled = false;
sighandler_t Tty::mOldHandler = nullptr;
Tty::PidTtyMap Tty::mPidTtyMap;

//
//
//

const int UTF_SIZE = 4;

struct Glyph {
    char     c[UTF_SIZE];
    uint8_t  mode;
    uint8_t  state;
    uint16_t fg;
    uint16_t bg;
};

//
//
//

struct Line {
    //Glyph * glyphs;

    explicit Line(const std::string str) : _str(str) {}
    std::string _str;
};

std::ostream & operator << (std::ostream & ost, const Line & line) {
    ost << line._str;
    return ost;
}

// Circular buffer of lines. New lines are added to the end. Old lines
// are removed from the beginning when capacity is reached.
// When it's vertically shrunk you lose lines from the beginning.
class Buffer {
    Line   * _data;
    size_t   _capacity;
    size_t   _offset;
    size_t   _size;

public:
    explicit Buffer(size_t capacity) :
        _data(reinterpret_cast<Line *>(std::malloc(capacity * sizeof(Line)))),
        _capacity(capacity),
        _offset(0),
        _size(0)
    {
        ASSERT(_data, "malloc() failed.");
    }

    ~Buffer() {
        for (size_t i = 0; i != _size; ++i) {
            Line * l = ptrNth(i);
            l->~Line();
        }
        std::free(_data);
    }

    // Add a line to the end of the buffer. If there is sufficient capacity
    // then grow the buffer. Otherwise replace the last line.
    void add(const Line & line) {
        Line * l = ptrNth(_size);
        if (_size == _capacity) {
            *l = line;
            ++_offset;
        }
        else {
            new (l) Line(line);
            ++_size;
        }
    }

    size_t getSize() const {
        return _size;
    }

    size_t getCapacity() const {
        return _capacity;
    }

    const Line & getNth(size_t index) const {
        ASSERT(index < _size, "Index out of range.");
        return *ptrNth(index);
    }

protected:
    const Line * ptrNth(size_t index) const {
        size_t rawIndex = ((_offset + index) % _capacity);
        return reinterpret_cast<const Line *>(&_data[rawIndex]);
    }

    Line * ptrNth(size_t index) {
        size_t rawIndex = ((_offset + index) % _capacity);
        return reinterpret_cast<Line *>(&_data[rawIndex]);
    }
};

void dumpBuffer(const Buffer & buffer) {
    std::cout << "Lines: " << buffer.getSize() << std::endl;
    for (size_t i = 0; i != buffer.getSize(); ++i) {
        std::cout << i << " " << buffer.getNth(i) << std::endl;
    }
}

//
//
// Viewport into a vertical subset of a buffer
struct Viewport {
    uint16_t offset;      // offset from bottom of buffer
    uint16_t height;
};

struct Selection {
};

//
//
//

xcb_visualtype_t * get_root_visual_type(xcb_screen_t * s) {
  xcb_visualtype_t * visual_type = nullptr;

  for (xcb_depth_iterator_t depth_iter = xcb_screen_allowed_depths_iterator(s);
       depth_iter.rem;
       xcb_depth_next(&depth_iter))
  {
    xcb_visualtype_iterator_t visual_iter;

    for (visual_iter = xcb_depth_visuals_iterator(depth_iter.data);
         visual_iter.rem;
         xcb_visualtype_next(&visual_iter))
    {
      if (s->root_visual == visual_iter.data->visual_id) {
        visual_type = visual_iter.data;
        break;
      }
    }
  }

  return visual_type;
}

//
//
//

class Window : protected Tty::IObserver {
    xcb_connection_t  * mConnection;
    xcb_key_symbols_t * mKeySymbols;
    xcb_window_t        mWindow;
    xcb_visualtype_t  * mVisual;
    cairo_font_face_t * mFontFace;
    Tty                 mTty;
    uint16_t            mWidth;
    uint16_t            mHeight;

public:
    Window(xcb_connection_t  * connection,
           xcb_screen_t      * screen,
           xcb_key_symbols_t * keySymbols,
           cairo_font_face_t * font_face) :
        mConnection(connection),
        mKeySymbols(keySymbols),
        mWindow(0),
        mVisual(0),
        mFontFace(font_face),
        mTty(*this)
    {
        uint32_t values[2];
        values[0] = screen->white_pixel;
        values[1] =
            XCB_EVENT_MASK_KEY_PRESS | XCB_EVENT_MASK_KEY_RELEASE |
            XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE |
            //XCB_EVENT_MASK_ENTER_WINDOW | XCB_EVENT_MASK_LEAVE_WINDOW |
            //XCB_EVENT_MASK_POINTER_MOTION_HINT |
            //XCB_EVENT_MASK_BUTTON_MOTION |
            XCB_EVENT_MASK_EXPOSURE |
            XCB_EVENT_MASK_STRUCTURE_NOTIFY |
            //XCB_EVENT_MASK_FOCUS_CHANGE |
            0;

        uint64_t width = 320, height = 240;

        mWindow = xcb_generate_id(mConnection);
        xcb_create_window(mConnection,
                          XCB_COPY_FROM_PARENT,
                          mWindow,
                          screen->root,
                          -1, -1,       // x, y     (XXX correct?)
                          width, height,
                          0,            // border width
                          XCB_WINDOW_CLASS_INPUT_OUTPUT,
                          screen->root_visual,
                          XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK,
                          values);

        xcb_map_window(mConnection, mWindow);
        xcb_flush(mConnection);

        mVisual = get_root_visual_type(screen);

        mTty.open(80, 24, "1234", "blah-term");
    }

    virtual ~Window() {
        xcb_destroy_window(mConnection, mWindow);
    }

    int getFd() {
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

    void keyPress(xcb_key_press_event_t * event) {
        #if 0
typedef struct xcb_key_press_event_t {
    uint8_t         response_type; /**<  */
    xcb_keycode_t   detail; /**<  */
    uint16_t        sequence; /**<  */
    xcb_timestamp_t time; /**<  */
    xcb_window_t    root; /**<  */
    xcb_window_t    event; /**<  */
    xcb_window_t    child; /**<  */
    int16_t         root_x; /**<  */
    int16_t         root_y; /**<  */
    int16_t         event_x; /**<  */
    int16_t         event_y; /**<  */
    uint16_t        state; /**<  */
    uint8_t         same_screen; /**<  */
    uint8_t         pad0; /**<  */
} xcb_key_press_event_t;
#endif

        /* Remove the numlock bit, all other bits are modifiers we can bind to */
        int state_filtered = event->state; //& ~(XCB_MOD_MASK_LOCK);
        /* Only use the lower 8 bits of the state (modifier masks) so that mouse
         *      * button masks are filtered out */
        //state_filtered &= 0xFF;

        xcb_keysym_t sym =
            xcb_key_press_lookup_keysym(mKeySymbols, event, state_filtered);

#if 0
        std::ostringstream modifiers;
        if (event->state & XCB_MOD_MASK_SHIFT)   { modifiers << "SHIFT "; }
        if (event->state & XCB_MOD_MASK_LOCK)    { modifiers << "LOCK "; }
        if (event->state & XCB_MOD_MASK_CONTROL) { modifiers << "CTRL "; }
        if (event->state & XCB_MOD_MASK_1)       { modifiers << "ALT "; }
        if (event->state & XCB_MOD_MASK_2)       { modifiers << "2 "; }
        if (event->state & XCB_MOD_MASK_3)       { modifiers << "3 "; }
        if (event->state & XCB_MOD_MASK_4)       { modifiers << "WIN "; }
        if (event->state & XCB_MOD_MASK_5)       { modifiers << "5 "; }

        PRINT("detail: " << event->detail <<
              ", seq: " << event->sequence <<
              ", state: " << event->state << " " <<
              ", sym: " << sym <<
              ", ascii(int): " << (sym & 0x7f) <<
              ", modifiers: " << modifiers.str());
#endif

        // TODO check sym against shortcuts

        if (true || isascii(sym)) {
            char a = sym & 0x7f;
            mTty.enqueue(&a, 1);
        }
    }

    void keyRelease(xcb_key_release_event_t * event) {
    }

    void buttonPress(xcb_button_press_event_t * event) {
        reinterpret_cast<xcb_button_press_event_t *>(event);
        ASSERT(event->event == mWindow, "Which window?");
        PRINT("Button-press: " << event->event_x << " " << event->event_y);

        xcb_get_geometry_reply_t * geometry =
            xcb_get_geometry_reply(mConnection, xcb_get_geometry(mConnection, mWindow), nullptr);

        PRINT("Geometry: " << geometry->x << " " << geometry->y << " " <<
              geometry->width << " " << geometry->height);

        std::free(geometry);
    }

    void buttonRelease(xcb_button_release_event_t * event) {
    }

    void expose(xcb_expose_event_t * event) {
        ASSERT(event->window == mWindow, "Which window?");
        PRINT("Expose: " <<
              event->x << " " << event->y << " " <<
              event->width << " " << event->height);

#if 0
        xcb_clear_area(mConnection,
                       0,   // exposures ??
                       mWindow,
                       event->x,
                       event->y,
                       event->width,
                       event->height);
#else
        xcb_clear_area(mConnection,
                       0,   // exposures ??
                       mWindow,
                       0, 0, mWidth, mHeight);
#endif

        cairo_surface_t * surface = cairo_xcb_surface_create(mConnection,
                                                             mWindow,
                                                             mVisual,
                                                             mWidth, mHeight);

        cairo_t * cr = cairo_create(surface);

        cairo_set_source_rgba(cr, 0, 0, 0, 1);
        cairo_move_to(cr, 10, 40);
        cairo_set_font_face(cr, mFontFace);
        cairo_set_font_size(cr, 15);
        cairo_show_text(cr, "(_Hello World.");

        if (cairo_status(cr)) {
          printf("Cairo is unhappy: %s\n",
                 cairo_status_to_string(cairo_status(cr)));
          exit(0);
        }

        cairo_destroy(cr);

        cairo_surface_destroy(surface);

        xcb_flush(mConnection);
    }

    void configure(xcb_configure_notify_event_t * event) {
        ASSERT(event->window == mWindow, "Which window?");
        PRINT("Configure notify: " <<
              event->x << " " << event->y << " " <<
              event->width << " " << event->height);

        mWidth  = event->width;
        mHeight = event->height;
    }

protected:
    // Tty::IObserver implementation:

    void readResults(const char * data, size_t length) throw () {
        for (size_t i = 0; i != length; ++i) {
            if (isascii(data[i])) {
                PRINT("Got ascii: " << int(data[i]) << ": " << data[i]);
            }
            else {
                PRINT("Got other: " << int(data[i]));
            }
        }
    }

    void childExited(int exitStatus) throw () {
        PRINT("Child exited: " << exitStatus);
    }
};

//
//
//

class SimpleEventLoop {
    xcb_connection_t  * mConnection;
    xcb_screen_t      * mScreen;
    xcb_key_symbols_t * mKeySymbols;
    Window            * mWindow;
public:
    SimpleEventLoop(cairo_font_face_t * font_face) :
        mConnection(nullptr),
        mScreen(nullptr),
        mKeySymbols(nullptr),
        mWindow(nullptr)
    {
        int screenNum;
        mConnection = ::xcb_connect(nullptr, &screenNum);

        const xcb_setup_t * setup = ::xcb_get_setup(mConnection);
        xcb_screen_iterator_t screenIter = ::xcb_setup_roots_iterator(setup);
        for (int i = 0; i != screenNum; ++i) { ::xcb_screen_next(&screenIter); }
        mScreen = screenIter.data;

        mKeySymbols = xcb_key_symbols_alloc(mConnection);

        mWindow = new Window(mConnection, mScreen, mKeySymbols, font_face);
    }

    ~SimpleEventLoop() {
        delete mWindow;

        xcb_key_symbols_free(mKeySymbols);

        ::xcb_disconnect(mConnection);
    }

    void run() {
        for (;;) {
            int fdMax = 0;
            fd_set readFds, writeFds;
            FD_ZERO(&readFds); FD_ZERO(&writeFds);

            FD_SET(xcb_get_file_descriptor(mConnection), &readFds);
            fdMax = std::max(fdMax, xcb_get_file_descriptor(mConnection));

            FD_SET(mWindow->getFd(), &readFds);
            fdMax = std::max(fdMax, mWindow->getFd());

            if (!mWindow->queueEmpty()) {
                FD_SET(mWindow->getFd(), &writeFds);
                fdMax = std::max(fdMax, mWindow->getFd());
            }

            if (::select(std::max(mWindow->getFd(),
                                  xcb_get_file_descriptor(mConnection)) + 1,
                         &readFds, nullptr, nullptr, nullptr) == -1) {
                ASSERT(false, "select() failed.");
            }

            if (FD_ISSET(xcb_get_file_descriptor(mConnection), &readFds)) {
                //PRINT("xevent");
                xevent();
            }

            if (FD_ISSET(mWindow->getFd(), &readFds)) {
                //PRINT("window read event");
                mWindow->read();
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
        xcb_generic_event_t * event = ::xcb_poll_for_event(mConnection);
        if (!event) {
            PRINT("No event!");
            return;
        }
        //bool send_event = XCB_EVENT_SENT(event);
        uint8_t response_type = XCB_EVENT_RESPONSE_TYPE(event);

        ASSERT(response_type != 0, "Error (according to awesome).");

        switch (response_type) {
            case XCB_KEY_PRESS:
                mWindow->keyPress(reinterpret_cast<xcb_key_press_event_t *>(event));
                break;
            case XCB_KEY_RELEASE:
                mWindow->keyRelease(reinterpret_cast<xcb_key_release_event_t *>(event));
                break;
            case XCB_BUTTON_PRESS:
                mWindow->buttonPress(reinterpret_cast<xcb_button_press_event_t *>(event));
                break;
            case XCB_BUTTON_RELEASE:
                mWindow->buttonRelease(reinterpret_cast<xcb_button_release_event_t *>(event));
                break;
            case XCB_EXPOSE:
                mWindow->expose(reinterpret_cast<xcb_expose_event_t *>(event));
                break;
            case XCB_MAP_NOTIFY:
                PRINT("Got map notify");
                break;
            case XCB_REPARENT_NOTIFY:
                PRINT("Got reparent notify");
                break;
            case XCB_CONFIGURE_NOTIFY:
                mWindow->configure(reinterpret_cast<xcb_configure_notify_event_t *>(event));
                break;
            default:
                PRINT("Unrecognised event: " << static_cast<int>(response_type));
                break;
        }
        std::free(event);
    }
};

//
//
//

int main() {
    // Global initialisation

    FT_Library ft_library;
    if (FT_Init_FreeType(&ft_library) != 0) {
        FATAL("Freetype init failed.");
    }

    FT_Face ft_face;
    if (FT_New_Face(ft_library, "/usr/share/fonts/TTF/ttf-inconsolata.otf",
                    0, &ft_face) != 0)
    {
        FATAL("FT_New_Face failed.");
    }

    cairo_font_face_t * font_face =
        cairo_ft_font_face_create_for_ft_face(ft_face, 0);
    ASSERT(font_face, "Couldn't load font.");

    Tty::installHandler();

    // Crank up the instance.

    SimpleEventLoop eventLoop(font_face);
    eventLoop.run();

    // Global finalisation.

    Tty::uninstallHandler();

    cairo_font_face_destroy(font_face);

    FT_Done_Face(ft_face);
    FT_Done_FreeType(ft_library);

    return 0;
}

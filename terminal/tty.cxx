// vi:noai:sw=4

#include "terminal/tty.hxx"

#include <sstream>

#include <unistd.h>
#include <pty.h>
#include <pwd.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/types.h>

namespace {

std::string strArgs(const std::vector<int32_t> & args) {
    std::ostringstream str;
    bool first = true;
    for (auto a : args) {
        if (first) { first = false; }
        else       { str << " "; }
        str << a;
    }
    return str.str();
}

int32_t nthArg(const std::vector<int32_t> & args, size_t n) {
    ASSERT(n < args.size(),);
    return args[n];
}

int32_t nthArgFallback(const std::vector<int32_t> & args, size_t n, int32_t fallback) {
    if (n < args.size()) {
        return args[n];
    }
    else {
        return fallback;
    }
}

} // namespace {anonymous}

Tty::Tty(IObserver         & observer,
         uint16_t            rows,
         uint16_t            cols,
         const std::string & windowId,
         const std::string & term,
         const Command     & command) :
    mObserver(observer),
    mDispatch(false),
    mFd(-1),
    mPid(0),
    mDumpWrites(false),
    mState(STATE_NORMAL)
{
    openPty(rows, cols, windowId, term, command);
}


Tty::~Tty() {
    if (isOpen()) {
        close();
    }
}

bool Tty::isOpen() const {
    ASSERT(!mDispatch,);
    return mFd != -1;
}

int Tty::getFd() {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    return mFd;
}

void Tty::read() {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    char buffer[4096];

    ssize_t rval = ::read(mFd, static_cast<void *>(buffer), sizeof buffer);
    //PRINT("::read()=" << rval);

    if (rval == -1) {
        mObserver.ttyChildExited(close());

    }
    else if (rval == 0) {
        ASSERT(false, "Expected -1 from ::read(), not EOF for child termination.");
    }
    else {
        ASSERT(rval > 0,);
        auto oldSize = mReadBuffer.size();
        mReadBuffer.resize(oldSize + rval);
        std::copy(buffer, buffer + rval, &mReadBuffer[oldSize]);

        mDispatch = true;
        processBuffer();
        mDispatch = false;
    }
}

void Tty::enqueueWrite(const char * data, size_t size) {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");

    if (!mDumpWrites) {
        auto oldSize = mWriteBuffer.size();
        mWriteBuffer.resize(oldSize + size);
        std::copy(data, data + size, &mWriteBuffer[oldSize]);
    }
}

bool Tty::isWritePending() const {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    return !mWriteBuffer.empty();
}

void Tty::write() {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    ASSERT(isWritePending(), "No writes queued.");
    ASSERT(!mDumpWrites, "Dump writes is set.");

    ssize_t rval = ::write(mFd, static_cast<const void *>(&mWriteBuffer.front()),
                           mWriteBuffer.size());
    //PRINT("::write()=" << rval);

    if (rval == -1) {
        // The child has gone. Don't write any more data.
        mDumpWrites = true;
        mWriteBuffer.clear();
    }
    else if (rval == 0) {
        ASSERT(false, "::write() zero bytes!");
    }
    else {
        mWriteBuffer.erase(mWriteBuffer.begin(), mWriteBuffer.begin() + rval);
    }
}

void Tty::resize(uint16_t rows, uint16_t cols) {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");

    struct winsize winsize = { rows, cols, 0, 0 };

    ENFORCE(::ioctl(mFd, TIOCSWINSZ, &winsize) != -1,);
}

void Tty::openPty(uint16_t            rows,
                  uint16_t            cols,
                  const std::string & windowId,
                  const std::string & term,
                  const Command     & command) {
    int master, slave;
    struct winsize winsize = { rows, cols, 0, 0 };

    ENFORCE_SYS(::openpty(&master, &slave, nullptr, nullptr, &winsize) != -1,);

    mPid = ::fork();
    ENFORCE_SYS(mPid != -1, "::fork() failed.");

    if (mPid != 0) {
        // Parent code-path.

        ENFORCE_SYS(::close(slave) != -1,);
        mFd  = master;
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
        execShell(windowId, term, command);
    }
}

void Tty::execShell(const std::string & windowId,
                    const std::string & term,
                    const Command     & command) {
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
    ::setenv("TERM", term.c_str(), 1);

    ::signal(SIGCHLD, SIG_DFL);
    ::signal(SIGHUP,  SIG_DFL);
    ::signal(SIGINT,  SIG_DFL);
    ::signal(SIGQUIT, SIG_DFL);
    ::signal(SIGTERM, SIG_DFL);
    ::signal(SIGALRM, SIG_DFL);

    std::vector<const char *> args;

    if (command.empty()) {
        const char * shell = std::getenv("SHELL");
        if (!shell) {
            shell = "/bin/sh";
            WARNING("Could not determine shell, falling back to: " << shell);
        }
        shell = "/bin/sh"; // XXX use sh to avoid colour, etc. (remove this line)
        args.push_back(shell);
        args.push_back("-i");
    }
    else {
        for (const auto & a : command) {
            args.push_back(a.c_str());
        }
    }

    args.push_back(nullptr);
    ::execvp(args[0], const_cast<char * const *>(&args.front()));
    std::exit(127); // Same as ::system() for failed commands.
}

void Tty::processBuffer() {
    ASSERT(!mReadBuffer.empty(),);

    mObserver.ttyBegin();

    size_t i = 0;

    while (i != mReadBuffer.size()) {
        utf8::Length length = utf8::leadLength(mReadBuffer[i]);

        if (mReadBuffer.size() < i + length) {
            break;
        }

        processChar(&mReadBuffer[i], length);

        i += length;
    }

    mReadBuffer.erase(mReadBuffer.begin(), mReadBuffer.begin() + i);

    mObserver.ttyEnd();
}

void Tty::processChar(const char * s, utf8::Length length) {
    if (length == utf8::L1) {
        char ascii = s[0];

        if (mState == STATE_STR_ESCAPE) {
            switch (ascii) {
                case '\x1b':
                    mState = STATE_ESCAPE_START_STR;
                    break;
                case '\a':      // xterm backwards compatibility
                    processStrEscape();
                    mState = STATE_NORMAL;
                    mEscapeStr.clear();
                    break;
                default:
                    // XXX upper limit??
                    mEscapeStr.push_back(ascii);
                    break;
            }
        }
        else {
            bool isControl = ascii < '\x20' || ascii == '\x7f';

            if (isControl) {
                ASSERT(mState == STATE_NORMAL,);
                processControl(ascii);
            }
            else if (mState == STATE_ESCAPE_START) {
                processEscape(ascii);
            }
            else if (mState == STATE_ESCAPE_START_STR) {
                processEscapeStr(ascii);
            }
            else if (mState == STATE_CSI_ESCAPE) {
                mEscapeSeq.push_back(ascii);

                if (ascii >= 0x40 && ascii <= 0x7e) {
                    processCsiEscape();
                    mState = STATE_NORMAL;
                    mEscapeSeq.clear();
                }
            }
            else {
                mObserver.ttyUtf8(s, length);
            }
        }
    }
    else {
        if (mState != STATE_NORMAL) {
            ERROR("Got UTF-8 whilst state: " << mState);
        }

        mObserver.ttyUtf8(s, length);
    }
}

void Tty::processControl(char c) {
    ASSERT(mState == STATE_NORMAL,);

    switch (c) {
        case '\a':
            mObserver.ttyControl(CONTROL_BEL);
            break;
        case '\t':
            mObserver.ttyControl(CONTROL_HT);
            break;
        case '\b':
            mObserver.ttyControl(CONTROL_BS);
            break;
        case '\r':
            mObserver.ttyControl(CONTROL_CR);
            break;
        case '\f':
        case '\v':
        case '\n':
            mObserver.ttyControl(CONTROL_LF);
            break;
        case '\x1b':
            // ESC start
            //PRINT("Escape sequence started.");
            mState = STATE_ESCAPE_START;
            break;
        default:
            PRINT("Ignored control char: " << int(c));
            break;
    }
}

void Tty::processEscape(char c) {
    ASSERT(mState == STATE_ESCAPE_START,);

    switch (c) {
        case '[':
            // CSI
            mState = STATE_CSI_ESCAPE;
            break;
        case '#':
            // test
            mState = STATE_TEST_ESCAPE;
            break;
        case 'P':
        case '_': /* APC -- Application Program Command */
        case '^': /* PM -- Privacy Message */
        case ']': /* OSC -- Operating System Command */
        case 'k': /* old title set compatibility */
            mEscapeStrType = c;
            mState = STATE_STR_ESCAPE;
            break;
        case '(':
            // alt char set
            break;
        case ')':
        case '*':
        case '+':
            mState = STATE_NORMAL;
            break;
        case 'D':   // IND - linefeed
            // TODO
            mState = STATE_NORMAL;
            break;
        case 'E':   // NEL - next line
            // TODO
            mState = STATE_NORMAL;
            break;
        case 'H':   // HTS - Horizontal tab stop.
            mState = STATE_NORMAL;
            break;
        case 'M':   // RI - Reverse index.
            // TODO
            mState = STATE_NORMAL;
            break;
        case 'Z':   // DECID -- Identify Terminal
            //ttywrite(VT102ID, sizeof(VT102ID) - 1);
            mState = STATE_NORMAL;
            break;
        case 'c':   // RIS - Reset to initial state
            //treset();
            //xresettitle();
            mState = STATE_NORMAL;
            break;
        case '=':   // DECPAM - Application keypad
            //term.mode |= MODE_APPKEYPAD;
            mState = STATE_NORMAL;
            break;
        case '>':   // DECPNM - Normal keypad
            //term.mode &= ~MODE_APPKEYPAD;
            mState = STATE_NORMAL;
            break;
        case '7':   // DECSC - Save Cursor
            //tcursor(CURSOR_SAVE);
            mState = STATE_NORMAL;
            break;
        case '8':   // DECRC - Restore Cursor
            //tcursor(CURSOR_LOAD);
            mState = STATE_NORMAL;
            break;
        case '\\': // ST -- Stop
            if (mState == STATE_STR_ESCAPE) {
                processStrEscape();
                mEscapeStr.clear();
            }
            mState = STATE_NORMAL;
            break;
        case 'm':
            break;
        default:
            ERROR("Unknown escape sequence: " << c);
            mState = STATE_NORMAL;
            break;
    }
}

void Tty::processEscapeStr(char c) {
    ASSERT(mState == STATE_ESCAPE_START_STR,);

    switch (c) {
        case '\\':
            processStrEscape();
            break;
        default:
            break;
    }

    mState = STATE_NORMAL;
}

void Tty::processCsiEscape() {
    ENFORCE(mState == STATE_CSI_ESCAPE,);       // XXX here or outside?
    ASSERT(!mEscapeSeq.empty(),);
    //PRINT("CSI-esc: " << mEscapeSeq);

    size_t i = 0;
    bool priv = false;
    std::vector<int32_t> args;

    if (mEscapeSeq.front() == '?') {
        ++i;
        priv = true;
    }

    bool inArg = false;

    while (i != mEscapeSeq.size()) {
        char c = mEscapeSeq[i];

        if (c >= '0' && c <= '9') {
            if (!inArg) {
                args.push_back(0);
                inArg = true;
            }
            args.back() = 10 * args.back() + c - '0';
        }
        else {
            if (inArg) {
                inArg = false;
            }

            if (c != ';') {
                break;
            }
        }

        ++i;
    }

    if (i == mEscapeSeq.size()) {
        ERROR("Bad CSI: " << mEscapeSeq);
    }
    else {
        char mode = mEscapeSeq[i];
        switch (mode) {
            case 'h':
                //PRINT(<<"CSI: Set terminal mode: " << strArgs(args));
                processMode(priv, true, args);
                break;
            case 'l':
                //PRINT(<<"CSI: Reset terminal mode: " << strArgs(args));
                processMode(priv, false, args);
                break;
            case 'K':   // EL - Clear line
                switch (nthArg(args, 0)) {
                    case 0: // right
                        mObserver.ttyClearLine(CLEAR_LINE_RIGHT);
                        break;
                    case 1: // left
                        mObserver.ttyClearLine(CLEAR_LINE_LEFT);
                        break;
                    case 2: // all
                        mObserver.ttyClearLine(CLEAR_LINE_ALL);
                        break;
                }
                break;
            case 'g':
                PRINT(<<"CSI: Tabulation clear");
                break;
            case 'H':
            case 'f': {
                uint16_t row = nthArgFallback(args, 0, 1) - 1;
                uint16_t col = nthArgFallback(args, 1, 1) - 1;
                //PRINT("CSI: Move cursor: row=" << row << ", col=" << col);
                mObserver.ttyMoveCursor(row, col);
            }
                break;
            //case '!':
                //break;
            case 'J':
                // Clear screen.
                switch (nthArg(args, 0)) {
                    case 0:
                        // below
                        mObserver.ttyClearScreen(CLEAR_SCREEN_BELOW);
                        break;
                    case 1:
                        // above
                        mObserver.ttyClearScreen(CLEAR_SCREEN_ABOVE);
                        break;
                    case 2:
                        // all
                        mObserver.ttyClearScreen(CLEAR_SCREEN_ALL);
                        break;
                    default:
                        FATAL("");
                }
                break;
            case 'm':
                processAttributes(args);
                break;
            default:
                PRINT(<<"CSI: UNKNOWN: mode=" << mode << ", priv=" << priv << ", args: " << strArgs(args));
                break;
        }
    }
}

void Tty::processStrEscape() {
    ENFORCE(mState == STATE_STR_ESCAPE,);       // XXX here or outside?
    PRINT("STR-esc: " << mEscapeStr);
}

void Tty::processAttributes(const std::vector<int32_t> & args) {
    for (size_t i = 0; i != args.size(); ++i) {
        int32_t v = args[i];

        switch (v) {
            case 0:
                mObserver.ttySetBg(defaultBg());
                mObserver.ttySetFg(defaultFg());
                mObserver.ttyClearAttributes();
                break;
            case 1:
                mObserver.ttyEnableAttribute(ATTRIBUTE_BOLD);
                break;
            case 3:
                mObserver.ttyEnableAttribute(ATTRIBUTE_ITALIC);
                break;
            case 4:
                mObserver.ttyEnableAttribute(ATTRIBUTE_UNDERLINE);
                break;
            case 5: // slow blink
            case 6: // rapid blink
                mObserver.ttyEnableAttribute(ATTRIBUTE_BLINK);
                break;
            case 7:
                mObserver.ttyEnableAttribute(ATTRIBUTE_REVERSE);
                break;
            case 21:
            case 22:
                mObserver.ttyDisableAttribute(ATTRIBUTE_BOLD);
                break;
            case 23:
                mObserver.ttyDisableAttribute(ATTRIBUTE_ITALIC);
                break;
            case 24:
                mObserver.ttyDisableAttribute(ATTRIBUTE_UNDERLINE);
                break;
            case 25:
            case 26:
                mObserver.ttyDisableAttribute(ATTRIBUTE_BLINK);
                break;
            case 27:
                mObserver.ttyDisableAttribute(ATTRIBUTE_REVERSE);
                break;
            case 38:
                if (i + 2 < args.size() && args[i + 1] == 5) {
                    i += 2;
                    int32_t v2 = args[i];
                    if (v2 >= 0 && v2 < 256) {
                        mObserver.ttySetFg(v2);
                    }
                    else {
                        ERROR("Colour out of range: " << v2);
                    }
                }
                else {
                    ERROR("XXX");
                }
                break;
            case 39:
                mObserver.ttySetFg(defaultFg());
                break;
            case 48:
                if (i + 2 < args.size() && args[i + 1] == 5) {
                    i += 2;
                    int32_t v2 = args[i];
                    if (v2 >= 0 && v2 < 256) {
                        mObserver.ttySetBg(v2);
                    }
                    else {
                        ERROR("Colour out of range: " << v2);
                    }
                }
                else {
                    ERROR("XXX");
                }
                break;
            case 49:
                mObserver.ttySetBg(defaultBg());
                break;
            default:
                if (v >= 30 && v < 38) {
                    // normal fg
                    mObserver.ttySetFg(v - 30);
                }
                else if (v >= 40 && v < 48) {
                    // bright fg
                    mObserver.ttySetBg(v - 40);
                }
                else if (v >= 90 && v < 98) {
                    // normal bg
                    mObserver.ttySetFg(v - 90 + 8);
                }
                else if (v >= 100 && v < 108) {
                    // bright bg
                    mObserver.ttySetBg(v - 100 + 8);
                }
                else {
                    ERROR("Unhandled Blah");
                }
        }
    }
}

void Tty::processMode(bool priv, bool set, const std::vector<int32_t> & args) {
    PRINT("NYI: processMode: priv=" << priv << ", set=" <<
          set << ", args=" << strArgs(args));
}

bool Tty::pollReap(int & exitCode, int msec) {
    ASSERT(mPid != 0,);

    for (int i = 0; i != msec; ++i) {
        int stat;
        int rval = ::waitpid(mPid, &stat, WNOHANG);
        ENFORCE_SYS(rval != -1, "::waitpid() failed.");
        if (rval != 0) {
            ENFORCE(rval == mPid,);
            mPid = 0;
            exitCode = WIFEXITED(stat) ? WEXITSTATUS(stat) : EXIT_FAILURE;
            return true;
        }
        ::usleep(1000);     // 1ms
    }

    return false;
}

void Tty::waitReap(int & exitCode) {
    ASSERT(mPid != 0,);

    int stat;
    ENFORCE_SYS(::waitpid(mPid, &stat, 0) == mPid,);
    mPid = 0;
    exitCode = WIFEXITED(stat) ? WEXITSTATUS(stat) : EXIT_FAILURE;
}

int Tty::close() {
    ASSERT(isOpen(),);

    ENFORCE_SYS(::close(mFd) != -1,);
    mFd = -1;

    ::kill(mPid, SIGCONT);
    ::kill(mPid, SIGPIPE);

    int exitCode;
    if (pollReap(exitCode, 100)) { return exitCode; }
    PRINT("Sending SIGINT.");
    ::kill(mPid, SIGINT);
    if (pollReap(exitCode, 100)) { return exitCode; }
    PRINT("Sending SIGTERM.");
    ::kill(mPid, SIGTERM);
    if (pollReap(exitCode, 100)) { return exitCode; }
    PRINT("Sending SIGQUIT.");
    ::kill(mPid, SIGQUIT);
    if (pollReap(exitCode, 100)) { return exitCode; }
    PRINT("Sending SIGKILL.");
    ::kill(mPid, SIGKILL);
    waitReap(exitCode);
}

std::ostream & operator << (std::ostream & ost, Control control) {
    switch (control) {
        case CONTROL_BEL:
            return ost << "BEL";
        case CONTROL_HT:
            return ost << "HT";
        case CONTROL_BS:
            return ost << "BS";
        case CONTROL_CR:
            return ost << "CR";
        case CONTROL_LF:
            return ost << "LF";
    }

    FATAL(<< static_cast<int>(control));
}

std::ostream & operator << (std::ostream & ost, Tty::ClearScreen clear) {
    switch (clear) {
        case Tty::CLEAR_SCREEN_BELOW:
            return ost << "BELOW";
        case Tty::CLEAR_SCREEN_ABOVE:
            return ost << "ABOVE";
        case Tty::CLEAR_SCREEN_ALL:
            return ost << "ALL";
    }

    FATAL(<< static_cast<int>(clear));
}

std::ostream & operator << (std::ostream & ost, Tty::ClearLine clear) {
    switch (clear) {
        case Tty::CLEAR_LINE_RIGHT:
            return ost << "RIGHT";
        case Tty::CLEAR_LINE_LEFT:
            return ost << "LEFT";
        case Tty::CLEAR_LINE_ALL:
            return ost << "ALL";
    }

    FATAL(<< static_cast<int>(clear));
}

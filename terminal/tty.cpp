// vi:noai:sw=4

#include "terminal/tty.hpp"

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
    PRINT("::read()=" << rval);

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

void Tty::enqueue(const char * data, size_t size) {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");

    if (!mDumpWrites) {
        auto oldSize = mWriteBuffer.size();
        mWriteBuffer.resize(oldSize + size);
        std::copy(data, data + size, &mWriteBuffer[oldSize]);
    }
}

bool Tty::isQueueEmpty() const {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    return mWriteBuffer.empty();
}

void Tty::write() {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");
    ASSERT(!isQueueEmpty(), "No writes queued.");
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
        bool isControl = ascii < '\x20' || ascii == '\x7f';

        if (isControl) {
            processControl(ascii);
        }
        else if (mState == STATE_ESCAPE_START) {
            processEscape(ascii);
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
    else {
        if (mState != STATE_NORMAL) {
            ERROR("Got UTF-8 whilst in escape seq.");
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
            PRINT("Ignored char: " << int(c));
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
            // ???
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
            mState = STATE_NORMAL;
            break;
        case 'm':
            break;
        default:
            ERROR("Unknown escape sequence.");
            mState = STATE_NORMAL;
            break;
    }
}

void Tty::processCsiEscape() {
    ENFORCE(mState == STATE_CSI_ESCAPE,);
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
                PRINT(<<"CSI: Set terminal mode: " << strArgs(args));
                break;
            case 'g':
                PRINT(<<"CSI: Tabulation clear");
                break;
            case 'H':
            case 'f': {
                uint16_t row = nthArgFallback(args, 0, 1) - 1;
                uint16_t col = nthArgFallback(args, 1, 1) - 1;
                PRINT("CSI: Move cursor: row=" << row << ", col=" << col);
                mObserver.ttyMoveCursor(row, col);
            }
                break;
            //case '!':
                //break;
            case 'l':
                PRINT(<<"CSI: Reset terminal mode: priv=" << priv << ", args: " << strArgs(args));
                break;
            case 'J':
                // Clear screen.
                switch (nthArg(args, 0)) {
                    case 0:
                        // below
                        mObserver.ttyClear(CLEAR_BELOW);
                        break;
                    case 1:
                        // above
                        mObserver.ttyClear(CLEAR_ABOVE);
                        break;
                    case 2:
                        // all
                        mObserver.ttyClear(CLEAR_ALL);
                        break;
                    default:
                        FATAL("");
                }
                break;
            case 'm':
                processBlah(args);
                break;
            default:
                PRINT(<<"CSI: UNKNOWN: mode=" << mode << ", priv=" << priv << ", args: " << strArgs(args));
                break;
        }
    }
}

void Tty::processBlah(const std::vector<int32_t> & args) {
    for (size_t i = 0; i != args.size(); ++i) {
        int32_t v = args[i];

        switch (v) {
            case 0:
                mObserver.ttySetFg(0);
                mObserver.ttySetBg(0);
                break;
            case 38:
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

std::ostream & operator << (std::ostream & ost, Tty::Control control) {
    switch (control) {
        case Tty::CONTROL_BEL:
            ost << "BEL";
            break;
        case Tty::CONTROL_HT:
            ost << "HT";
            break;
        case Tty::CONTROL_BS:
            ost << "BS";
            break;
        case Tty::CONTROL_CR:
            ost << "CR";
            break;
        case Tty::CONTROL_LF:
            ost << "LF";
            break;
    }

    return ost;
}

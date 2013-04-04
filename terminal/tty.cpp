// vi:noai:sw=4

#include "terminal/tty.hpp"

#include <unistd.h>
#include <pty.h>
#include <pwd.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <sys/types.h>

Tty::Tty(IObserver         & observer,
         uint16_t            cols,
         uint16_t            rows,
         const std::string & windowId,
         const std::string & term,
         const Command     & command) :
    mObserver(observer),
    mDispatch(false),
    mCols(cols),
    mRows(rows),
    mFd(-1),
    mPid(0),
    mDumpWrites(false),
    mInEscape(false),
    mInCsiEscape(false),
    mInTestEscape(false)
{
    openPty(windowId, term, command);
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
    char buffer[1024];

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
        std::copy(buffer, buffer + rval, &mReadBuffer[oldSize]);        // XXX illegal for deque

        mDispatch = true;
        dispatchBuffer();
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

void Tty::resize(uint16_t cols, uint16_t rows) {
    ASSERT(!mDispatch,);
    ASSERT(isOpen(), "Not open.");

    if (mCols != cols || mRows != rows) {
        mCols = cols;
        mRows = rows;
        struct winsize winsize = { mRows, mCols, 0, 0 };

        ENFORCE(::ioctl(mFd, TIOCSWINSZ, &winsize) != -1,);
    }
}

void Tty::openPty(const std::string & windowId,
                  const std::string & term,
                  const Command     & command) {
    int master, slave;
    struct winsize winsize = { mRows, mCols, 0, 0 };

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

void Tty::dispatchBuffer() {
    ASSERT(!mReadBuffer.empty(),);

    mObserver.ttyBegin();

    size_t i = 0;

    while (i != mReadBuffer.size()) {
        utf8::Length length = utf8::leadLength(mReadBuffer[i]);

        if (mReadBuffer.size() < i + length) {
            break;
        }

        dispatchChar(&mReadBuffer[i], length);

        i += length;
    }

    mReadBuffer.erase(mReadBuffer.begin(), mReadBuffer.begin() + i);

    mObserver.ttyEnd();
}

void Tty::dispatchChar(const char * s, utf8::Length length) {
    if (length == utf8::L1) {
        char ascii = s[0];
        bool isControl = ascii < '\x20' || ascii == '\x7f';

        if (isControl) {
            switch (s[0]) {
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
                    mInEscape = true;
                    break;
                default:
                    PRINT("Ignored char: " << int(s[0]));
                    break;
            }
        }
        else if (mInEscape) {
            //PRINT("esc: " << std::string(s, s + len));

            if (mInCsiEscape) {
                mEscapeSeq.push_back(ascii);

                if (ascii >= 0x40 && ascii <= 0x7e) {
                    PRINT("CSI-esc: " << mEscapeSeq);
                    mInEscape = mInCsiEscape = false;
                    mEscapeSeq.clear();
                }
            }
            else {
                switch (ascii) {
                    case '[':
                        // CSI
                        mInCsiEscape = true;
                        break;
                    case '#':
                        // test
                        mInTestEscape = true;
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
                        mInEscape = false;
                        break;
                    case 'D':   // IND - linefeed
                        // TODO
                        mInEscape = false;
                        break;
                    case 'E':   // NEL - next line
                        // TODO
                        mInEscape = false;
                        break;
                    case 'H':   // HTS - Horizontal tab stop.
                        mInEscape = false;
                        break;
                    case 'M':   // RI - Reverse index.
                        // TODO
                        mInEscape = false;
                        break;
                    case 'Z':   // DECID -- Identify Terminal
                        //ttywrite(VT102ID, sizeof(VT102ID) - 1);
                        mInEscape = false;
                        break;
                    case 'c':   // RIS - Reset to initial state
                        //treset();
                        //xresettitle();
                        mInEscape = false;
                        break;
                    case '=':   // DECPAM - Application keypad
                        //term.mode |= MODE_APPKEYPAD;
                        mInEscape = false;
                        break;
                    case '>':   // DECPNM - Normal keypad
                        //term.mode &= ~MODE_APPKEYPAD;
                        mInEscape = false;
                        break;
                    case '7':   // DECSC - Save Cursor
                        //tcursor(CURSOR_SAVE);
                        mInEscape = false;
                        break;
                    case '8':   // DECRC - Restore Cursor
                        //tcursor(CURSOR_LOAD);
                        mInEscape = false;
                        break;
                    case '\\': // ST -- Stop
                        mInEscape = false;
                        break;
                    default:
                        ERROR("Unknown escape sequence.");
                        mInEscape = false;
                        break;
                }
            }
        }
        else {
            mObserver.ttyUtf8(s, length);
        }
    }
    else {
        if (mInEscape) {
            ERROR("Got UTF-8 whilst in escape seq.");
        }

        mObserver.ttyUtf8(s, length);
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

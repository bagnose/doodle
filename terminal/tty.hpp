#ifndef TTY__H
#define TTY__H

#include <pty.h>
#include <sys/wait.h>
#include <sys/ioctl.h>

#include "terminal/common.hpp"

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
    bool                mDumpWrites;
    std::deque<char>    mWriteBuffer;

public:
    explicit Tty(IObserver & observer) :
        mObserver(observer),
        mOpen(false),
        mRows(0),
        mColumns(0),
        mFd(-1),
        mPid(0),
        mDumpWrites(false)
    {
    }

    ~Tty() {
        if (mOpen) {
            // wait pid?
            ENFORCE_SYS(::close(mFd) != -1,);
        }
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

    bool isOpen() const {
        return mOpen;
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
            ENFORCE_SYS(::close(mFd) != -1,);

            int stat;
            ENFORCE_SYS(::waitpid(mPid, &stat, 0) != -1,);
            int exitCode = WIFEXITED(stat) ? WEXITSTATUS(stat) : EXIT_FAILURE;

            mPid  = 0;
            mOpen = false;

            mObserver.childExited(exitCode);
        }
        else if (rval == 0) {
            ASSERT(false, "Expected -1 from ::read(), not EOF for child termination.");
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

        if (!mDumpWrites) {
            size_t oldSize = mWriteBuffer.size();
            mWriteBuffer.resize(oldSize + size);
            std::copy(data, data + size, &mWriteBuffer[oldSize]);
        }
    }

    void write() {
        ASSERT(mOpen, "Not open.");
        ASSERT(!queueEmpty(), "No writes queued.");
        ASSERT(!mDumpWrites, "Dump writes is set.");

        ssize_t rval = ::write(mFd, static_cast<const void *>(&mWriteBuffer.front()),
                               mWriteBuffer.size());

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
};

#endif // TTY__H

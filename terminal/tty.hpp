// vi:noai:sw=4

#ifndef TTY__HPP
#define TTY__HPP

#include "terminal/common.hpp"
#include "terminal/utf8.hpp"

#include <vector>
#include <string>

class Tty : protected Uncopyable {
public:
    enum Control {
        CONTROL_BEL,
        CONTROL_HT,
        CONTROL_BS,
        CONTROL_CR,
        CONTROL_LF
    };

    enum Clear {
        CLEAR_BELOW,
        CLEAR_ABOVE,
        CLEAR_ALL
    };

    typedef std::vector<std::string> Command;

    class IObserver {
    public:
        // begin
        virtual void ttyBegin() throw () = 0;
        // control
        virtual void ttyControl(Control control) throw () = 0;
        // escapes
        virtual void ttyMoveCursor(uint16_t row, uint16_t col) throw () = 0;
        virtual void ttyClear(Clear clear) throw () = 0;
        // UTF-8
        virtual void ttyUtf8(const char * s, utf8::Length length) throw () = 0;
        // end
        virtual void ttyEnd() throw () = 0;

        virtual void ttyChildExited(int exitCode) throw () = 0;

    protected:
        IObserver() throw () {}
        ~IObserver() throw () {}
    };

private:
    enum State {
        STATE_NORMAL,
        STATE_ESCAPE_START,
        STATE_CSI_ESCAPE,
        STATE_STR_ESCAPE,
        STATE_TEST_ESCAPE
    };

    IObserver         & mObserver;
    bool                mDispatch;
    int                 mFd;
    pid_t               mPid;
    bool                mDumpWrites;
    State               mState;
    std::string         mEscapeSeq;
    std::vector<char>   mReadBuffer;
    std::vector<char>   mWriteBuffer;

public:
    Tty(IObserver         & observer,
        uint16_t            cols,
        uint16_t            rows,
        const std::string & windowId,
        const std::string & term,
        const Command     & command);

    ~Tty();

    bool isOpen() const;

    // Only use the descriptor for select() - do not read/write().
    int  getFd();

    // Call when will not block (after select()).
    void read();

    // Queue data for write.
    void enqueue(const char * data, size_t size);

    // Is there data queued for write?
    bool isQueueEmpty() const;

    // Call when will not block (after select()).
    void write();

    // Number of rows or columns may have changed.
    void resize(uint16_t cols, uint16_t rows);

protected:
    void openPty(uint16_t            cols,
                 uint16_t            rows,
                 const std::string & windowId,
                 const std::string & term,
                 const Command     & command);

    // Called from the fork child.
    static void execShell(const std::string & windowId,
                          const std::string & term,
                          const Command     & command);

    void processBuffer();
    void processChar(const char * s, utf8::Length len);
    void processControl(char c);
    void processEscape(char c);
    void processCsiEscape();

    bool pollReap(int & exitCode, int msec);
    void waitReap(int & exitCode);

    // Returns exit-code.
    int  close();
};

std::ostream & operator << (std::ostream & ost, Tty::Control control);

#endif // TTY__HPP

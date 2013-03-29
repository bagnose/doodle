// vi:noai:sw=4

#ifndef TERMINAL__HPP
#define TERMINAL__HPP

#include "terminal/tty.hpp"

class Terminal : protected Tty::IObserver {
public:
    class IObserver {
    public:
        virtual void terminalBegin() throw () = 0;
        virtual void damageAll() throw () = 0;
        virtual void terminalEnd() throw () = 0;

    protected:
        IObserver() {}
        virtual ~IObserver() {}
    };

    typedef std::vector<std::string> Text;

private:
    IObserver & mObserver;
    Tty mTty;
    // XXX remove all this stuff:
    Text mText;

public:
    Terminal(IObserver & observer) :
        mObserver(observer),
        mTty(*this),
        mText(1, std::string())
    {
    }

    virtual ~Terminal() {}

    const Text & text() const { return mText; }

    // The following calls are forwarded to the Tty.

    void open(uint16_t             cols,
              uint16_t             rows,
              const std::string  & windowId,
              const std::string  & term,
              const Tty::Command & command) {
        mTty.open(cols, rows, windowId, term, command);
    }

    bool isOpen() const { return mTty.isOpen(); }
    int  getFd() { return mTty.getFd(); }
    void read() { mTty.read(); }
    void enqueue(const char * data, size_t size) { mTty.enqueue(data, size); }
    bool isQueueEmpty() const { return mTty.isQueueEmpty(); }
    void write() { mTty.write(); }
    void resize(uint16_t cols, uint16_t rows) { mTty.resize(cols, rows); }

protected:

    // Tty::IObserver implementation:

    void ttyBegin() throw ();

    void ttyControl(Tty::Control control) throw ();

    void ttyUtf8(const char * s, utf8::Length length) throw ();

    void ttyEnd() throw ();

    void ttyChildExited(int exitCode) throw ();
};

#endif // TERMINAL__HPP

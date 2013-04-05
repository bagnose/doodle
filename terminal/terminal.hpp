// vi:noai:sw=4

#ifndef TERMINAL__HPP
#define TERMINAL__HPP

#include "terminal/tty.hpp"
#include "terminal/buffer.hpp"

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
    IObserver     & _observer;
    WrappedBuffer   _buffer;
    size_t          _cursorRow;
    size_t          _cursorCol;
    Tty             _tty;

public:
    Terminal(IObserver          & observer,
             uint16_t             cols,
             uint16_t             rows,
             const std::string  & windowId,
             const std::string  & term,
             const Tty::Command & command) :
        _observer(observer),
        _buffer(cols, rows, 1024),
        _cursorRow(0),
        _cursorCol(0),
        _tty(*this,
             cols, rows,
             windowId,
             term,
             command) { }

    virtual ~Terminal() {}

    const WrappedBuffer & buffer() const { return _buffer; }
    size_t cursorCol() const { return _cursorCol; }
    size_t cursorRow() const { return _cursorRow; }

    // TODO buffer access through scroll state.

    bool isOpen() const { return _tty.isOpen(); }
    int  getFd() { return _tty.getFd(); }
    void read() { _tty.read(); }
    void enqueue(const char * data, size_t size) { _tty.enqueue(data, size); }
    bool isQueueEmpty() const { return _tty.isQueueEmpty(); }
    void write() { _tty.write(); }
    void resize(uint16_t cols, uint16_t rows);

protected:

    // Tty::IObserver implementation:

    void ttyBegin() throw ();
    void ttyControl(Tty::Control control) throw ();
    void ttyMoveCursor(uint16_t row, uint16_t col) throw ();
    void ttyClear(Tty::Clear clear) throw ();
    void ttyUtf8(const char * s, utf8::Length length) throw ();
    void ttyEnd() throw ();

    void ttyChildExited(int exitCode) throw ();
};

#endif // TERMINAL__HPP

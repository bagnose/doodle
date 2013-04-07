// vi:noai:sw=4

#ifndef TERMINAL__HPP
#define TERMINAL__HPP

#include "terminal/tty.hpp"
#include "terminal/simple_buffer.hpp"

class Terminal : protected Tty::IObserver {
public:
    class IObserver {
    public:
        virtual void terminalBegin() throw () = 0;
        //virtual void damage(uint16_t row, uint16_t col) throw () = 0;
        //virtual void damageRange(uint16_t row, uint16_t col) throw () = 0;
        virtual void damageAll() throw () = 0;
        virtual void terminalEnd() throw () = 0;

    protected:
        IObserver() {}
        virtual ~IObserver() {}
    };

private:
    IObserver     & _observer;
    SimpleBuffer    _buffer;
    uint16_t        _cursorRow;
    uint16_t        _cursorCol;
    uint8_t         _bg;
    uint8_t         _fg;
    Tty             _tty;

public:
    Terminal(IObserver          & observer,
             uint16_t             rows,
             uint16_t             cols,
             const std::string  & windowId,
             const std::string  & term,
             const Tty::Command & command);

    virtual ~Terminal();

    const SimpleBuffer & buffer() const { return _buffer; }
    size_t cursorCol() const { return _cursorCol; }
    size_t cursorRow() const { return _cursorRow; }

    // TODO buffer access through scroll state.

    bool isOpen() const { return _tty.isOpen(); }
    int  getFd() { return _tty.getFd(); }
    void read() { _tty.read(); }
    void enqueue(const char * data, size_t size) { _tty.enqueue(data, size); }
    bool isQueueEmpty() const { return _tty.isQueueEmpty(); }
    void write() { _tty.write(); }
    void resize(uint16_t rows, uint16_t cols);

protected:

    // Tty::IObserver implementation:

    void ttyBegin() throw ();
    void ttyControl(Tty::Control control) throw ();
    void ttyMoveCursor(uint16_t row, uint16_t col) throw ();
    void ttyClear(Tty::Clear clear) throw ();
    void ttySetFg(uint8_t fg) throw ();
    void ttySetBg(uint8_t bg) throw ();
    void ttyResetAttributes() throw ();
    void ttyEnableAttribute(Tty::Attribute atttribute) throw ();
    void ttyDisableAttribute(Tty::Attribute atttribute) throw ();
    void ttyUtf8(const char * s, utf8::Length length) throw ();
    void ttyEnd() throw ();

    void ttyChildExited(int exitCode) throw ();
};

#endif // TERMINAL__HPP

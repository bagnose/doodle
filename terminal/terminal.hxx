// vi:noai:sw=4

#ifndef TERMINAL__HXX
#define TERMINAL__HXX

#include "terminal/tty.hxx"
#include "terminal/bit_sets.hxx"
#include "terminal/simple_buffer.hxx"

#include <vector>

class Terminal : protected Tty::IObserver {
public:
    class IObserver {
    public:
        virtual void terminalBegin() throw () = 0;
        //virtual void terminalDamage(uint16_t row, uint16_t col) throw () = 0;
        //virtual void terminalDamageRange(uint16_t row, uint16_t col) throw () = 0;
        virtual void terminalDamageAll() throw () = 0;
        virtual void terminalEnd() throw () = 0;
        virtual void terminalChildExited(int exitStatus) throw () = 0;

    protected:
        IObserver() {}
        virtual ~IObserver() {}
    };

private:
    IObserver         & _observer;
    bool                _dispatch;
    SimpleBuffer        _buffer;
    uint16_t            _cursorRow;
    uint16_t            _cursorCol;
    uint8_t             _bg;
    uint8_t             _fg;
    AttributeSet        _attributes;
    std::vector<bool>   _tabs;
    Tty                 _tty;

public:
    Terminal(IObserver          & observer,
             uint16_t             rows,
             uint16_t             cols,
             const std::string  & windowId,
             const std::string  & term,
             const Tty::Command & command);

    virtual ~Terminal();

    const SimpleBuffer & buffer()    const { return _buffer;    }
    uint16_t             cursorRow() const { return _cursorRow; }
    uint16_t             cursorCol() const { return _cursorCol; }

    // TODO buffer access through scroll state.

    bool isOpen() const { return _tty.isOpen(); }
    int  getFd() { return _tty.getFd(); }
    void read() { ASSERT(!_dispatch,); _tty.read(); }
    void enqueueWrite(const char * data, size_t size) { ASSERT(!_dispatch,); _tty.enqueueWrite(data, size); }
    bool isWritePending() const { ASSERT(!_dispatch,); return _tty.isWritePending(); }
    void write() { ASSERT(!_dispatch,); _tty.write(); }
    void resize(uint16_t rows, uint16_t cols);

protected:

    // Tty::IObserver implementation:

    void ttyBegin() throw ();
    void ttyControl(Control control) throw ();
    void ttyMoveCursor(uint16_t row, uint16_t col) throw ();
    void ttyClearLine(ClearLine clear) throw ();
    void ttyClearScreen(ClearScreen clear) throw ();
    void ttySetFg(uint8_t fg) throw ();
    void ttySetBg(uint8_t bg) throw ();
    void ttyClearAttributes() throw ();
    void ttyEnableAttribute(Attribute attribute) throw ();
    void ttyDisableAttribute(Attribute attribute) throw ();
    void ttySetTabStop() throw ();
    void ttyEnableMode(Mode mode) throw ();
    void ttyDisableMode(Mode mode) throw ();
    void ttyUtf8(const char * s, utf8::Length length) throw ();
    void ttyEnd() throw ();

    void ttyChildExited(int exitCode) throw ();
};

#endif // TERMINAL__HXX

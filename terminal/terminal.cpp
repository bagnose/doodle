// vi:noai:sw=4

#include "terminal/terminal.hpp"

// Tty::IObserver implementation:

void Terminal::ttyBegin() throw () {
    _observer.terminalBegin();
}

void Terminal::ttyControl(Tty::Control control) throw () {
    PRINT("Control: " << control);
    switch (control) {
        case Tty::CONTROL_BEL:
            break;
        case Tty::CONTROL_HT:
            break;
        case Tty::CONTROL_BS:
            _buffer.eraseChar(_cursorRow, --_cursorCol);
            break;
        case Tty::CONTROL_CR:
            break;
        case Tty::CONTROL_LF:
            _buffer.addLine();
            _cursorCol = 0;
            ++_cursorRow;
            break;
        default:
            break;
    }

    _observer.damageAll();
}

void Terminal::ttyUtf8(const char * s, utf8::Length length) throw () {
    PRINT("UTF-8: '" << std::string(s, s + length) << "'");
    _buffer.insertChar(Char::utf8(s, length), _cursorRow, _cursorCol);
    // FIXME we should be writing without worrying about wrapping, right?
    ++_cursorCol;
    _observer.damageAll();
}

void Terminal::ttyEnd() throw () {
    _observer.terminalEnd();
}

void Terminal::ttyChildExited(int exitStatus) throw () {
    PRINT("Child exited: " << exitStatus);
}

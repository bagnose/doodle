// vi:noai:sw=4

#include "terminal/terminal.hxx"

Terminal::Terminal(IObserver          & observer,
                   uint16_t             rows,
                   uint16_t             cols,
                   const std::string  & windowId,
                   const std::string  & term,
                   const Tty::Command & command) :
    _observer(observer),
    _buffer(rows, cols),
    _cursorRow(0),
    _cursorCol(0),
    _bg(Tty::defaultBg()),
    _fg(Tty::defaultFg()),
    _tty(*this,
         rows, cols,
         windowId,
         term,
         command)
{
    _tabs.resize(cols);
    for (size_t i = 0; i != _tabs.size(); ++i) {
        _tabs[i] = (i + 1) % Tty::defaultTab() == 0;
    }
}

Terminal::~Terminal() {}

void Terminal::resize(uint16_t rows, uint16_t cols) {
    _buffer.resize(rows, cols);
    _tty.resize(rows, cols);
    _tabs.resize(cols);
    for (size_t i = 0; i != _tabs.size(); ++i) {
        _tabs[i] = (i + 1) % Tty::defaultTab() == 0;
    }
}

// Tty::IObserver implementation:

void Terminal::ttyBegin() throw () {
    _observer.terminalBegin();
}

void Terminal::ttyControl(Control control) throw () {
    //PRINT("Control: " << control);
    switch (control) {
        case CONTROL_BEL:
            break;
        case CONTROL_HT:
            for (; _cursorCol != _buffer.getCols(); ++_cursorCol) {
                if (_tabs[_cursorCol]) {
                    break;
                }
            }
            break;
        case CONTROL_BS:
            _buffer.eraseChar(_cursorRow, --_cursorCol);
            break;
        case CONTROL_CR:
            _cursorCol = 0;
            break;
        case CONTROL_LF:
            if (_cursorRow == _buffer.getRows() - 1) {
                _buffer.addLine();
            }
            else {
                ++_cursorRow;
            }
            break;
        default:
            break;
    }

    _observer.damageAll();
}

void Terminal::ttyMoveCursor(uint16_t row, uint16_t col) throw () {
    _cursorRow = row;
    _cursorCol = col;
}

void Terminal::ttyClearLine(Tty::ClearLine clear) throw () {
    switch (clear) {
        case Tty::CLEAR_LINE_RIGHT:
            for (uint16_t c = _cursorCol + 1; c != _buffer.getCols(); ++c) {
                _buffer.overwriteChar(Char::null(), _cursorRow, c);
            }
            break;
        case Tty::CLEAR_LINE_LEFT:
            for (uint16_t c = 0; c != _cursorCol; ++c) {
                _buffer.overwriteChar(Char::null(), _cursorRow, c);
            }
            break;
        case Tty::CLEAR_LINE_ALL:
            _buffer.clearLine(_cursorRow);
            break;
    }
}

void Terminal::ttyClearScreen(Tty::ClearScreen clear) throw () {
    switch (clear) {
        case Tty::CLEAR_SCREEN_BELOW:
            for (uint16_t r = _cursorRow + 1; r != _buffer.getRows(); ++r) {
                _buffer.clearLine(r);
            }
            break;
        case Tty::CLEAR_SCREEN_ABOVE:
            for (uint16_t r = 0; r != _cursorRow; ++r) {
                _buffer.clearLine(r);
            }
            break;
        case Tty::CLEAR_SCREEN_ALL:
            _buffer.clearAll();
            _cursorCol = _cursorRow = 0;
            break;
    }

    _observer.damageAll();
}

void Terminal::ttySetFg(uint8_t fg) throw () {
    _fg = fg;
}

void Terminal::ttySetBg(uint8_t bg) throw () {
    _bg = bg;
}

void Terminal::ttyClearAttributes() throw () {
    PRINT("Clearing attributes");
    _attributes.clear();
}

void Terminal::ttyEnableAttribute(Attribute attribute) throw () {
    PRINT("Enabling attribute: " << attribute);
    _attributes.set(attribute);
}

void Terminal::ttyDisableAttribute(Attribute attribute) throw () {
    PRINT("Disabling attribute: " << attribute);
    _attributes.unSet(attribute);
}

void Terminal::ttyUtf8(const char * s, utf8::Length length) throw () {
    //PRINT("UTF-8: '" << std::string(s, s + length) << "'");
    _buffer.overwriteChar(Char::utf8(s, length, _attributes, 0, _fg, _bg),
                          _cursorRow, _cursorCol);
    ++_cursorCol;

    if (_cursorCol == _buffer.getCols()) {
        ++_cursorRow;
        if (_cursorRow == _buffer.getRows()) {
            _buffer.addLine();
            --_cursorRow;
        }
        _cursorCol = 0;
    }

    _observer.damageAll();
}

void Terminal::ttyEnd() throw () {
    _observer.terminalEnd();
}

void Terminal::ttyChildExited(int exitStatus) throw () {
    PRINT("Child exited: " << exitStatus);
}

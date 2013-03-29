// vi:noai:sw=4

#include "terminal/terminal.hpp"

// Tty::IObserver implementation:

void Terminal::ttyBegin() throw () {
    mObserver.terminalBegin();
}

void Terminal::ttyControl(Tty::Control control) throw () {
    switch (control) {
        case Tty::CONTROL_BEL:
            break;
        case Tty::CONTROL_HT:
            break;
        case Tty::CONTROL_BS: {
            auto & line = mText.back();
            if (!line.empty()) {
                // FIXME broken for utf8
                mText.back().pop_back();
            }
        }
            break;
        case Tty::CONTROL_CR:
            break;
        case Tty::CONTROL_LF:
            mText.push_back(std::string());
            break;
        default:
            break;
    }

    mObserver.damageAll();
}

void Terminal::ttyUtf8(const char * s, utf8::Length length) throw () {
    ASSERT(!mText.empty(),);
    //PRINT("Got: " << std::string(s, s + len));

    auto & line = mText.back();
    auto oldSize = line.size();
    line.resize(oldSize + length);
    std::copy(s, s + length, &line[oldSize]);

    mObserver.damageAll();
}

void Terminal::ttyEnd() throw () {
    mObserver.terminalEnd();
}

void Terminal::ttyChildExited(int exitStatus) throw () {
    PRINT("Child exited: " << exitStatus);
}

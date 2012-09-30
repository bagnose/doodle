module doodle.core.logging;

private {
    import std.stdio;
    import std.typecons;
    import std.traits;
}

public {
    void trace(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.TRACE,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
    }

    void info(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.INFO,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
    }

    void message(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.MESSAGE,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
    }

    void warning(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.WARNING,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
    }

    void error(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.ERROR,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
    }

    void fatal(string file = __FILE__, int line = __LINE__, S...)(S args) {
        static assert(S.length > 0);
        static assert(isSomeString!(S[0]));
        log(Severity.FATAL,
            std.string.format("%s(%d): MESSAGE: %s", right(file, 20), line, std.string.format(args)));
        assert(0);
    }
}

private {
    enum Severity {
        TRACE,
        INFO,
        MESSAGE,
        WARNING,
        ERROR,
        FATAL
    };

    string severityString(in Severity s) {
        switch (s) {
        case Severity.TRACE:
            return modifierString(Modifier.DIM) ~ fgColorString(Color.CYAN);
        case Severity.INFO:
            return modifierString(Modifier.UNDERLINE) ~ fgColorString(Color.GREEN);
        case Severity.MESSAGE:
            return fgColorString(Color.YELLOW);
        case Severity.WARNING:
            return modifierString(Modifier.BRIGHT) ~ fgColorString(Color.MAGENTA);
        case Severity.ERROR:
            return modifierString(Modifier.BRIGHT) ~ fgColorString(Color.RED);
        case Severity.FATAL:
            return modifierString(Modifier.BRIGHT) ~ bgColorString(Color.RED) ~ fgColorString(Color.WHITE);
        default:
            assert(0);
        }
        assert(0);
    }

    void log(in Severity severity, in string message) {
        writeln(severityString(severity), message, modifierString(Modifier.RESET));
    }

    enum Modifier {
        RESET     = 0,
        BRIGHT    = 1,
        DIM       = 2,      // does nothing in gnome-terminal
        UNDERLINE = 3,      // does nothing in gnome-terminal
        BLINK     = 5,      // does nothing in gnome-terminal
        REVERSE   = 7,
        HIDDEN    = 8
    }

    enum Color {
        BLACK   = 0,
        RED     = 1,
        GREEN   = 2,
        YELLOW  = 3,
        BLUE    = 4,
        MAGENTA = 5,
        CYAN    = 6,
        WHITE   = 7
    }

    string modifierString(in Modifier m) { return std.string.format("\033[%dm", 0 + m); }
    string fgColorString(in Color c)     { return std.string.format("\033[%dm", 30 + c); }
    string bgColorString(in Color c)     { return std.string.format("\033[%dm", 40 + c); }

    private string right(in string str, in int n) {
        auto pos = str.length < n ? 0 : str.length - n;
        return str[pos..$];
    }
}

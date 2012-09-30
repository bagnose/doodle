module doodle.core.backtrace;

/+

//
// Provides support for a readable backtrace on a program crash.
//
// Everything is private - you build this into a library and
// link to the library, and bingo (via static this).
//
// It works by registering a stacktrace handler with the runtime,
// which, unlike the default one, provides demangled symbols
// rather than just a list of addresses.
//

private {

    import core.stdc.signal;
    import core.stdc.stdlib : free;
    import core.stdc.string : strlen;
    import core.runtime;
    import std.demangle;
    import std.string;

    extern (C) int    backtrace(void**, size_t);
    extern (C) char** backtrace_symbols(void**, int);

    // signal handler for otherwise-fatal thread-specific signals 
    extern (C) void signalHandler(int sig) {
        string name() {
            switch (sig) {
            case SIGSEGV: return "SIGSEGV";
            case SIGFPE:  return "SIGFPE";
            case SIGILL:  return "SIGILL";
            case SIGABRT: return "SIGABRT";
            case SIGINT:  return "SIGINT";
            default:      return "";
            }
        }

        throw new Error(format("Got signal %s %s", sig, name()));
    }

    shared static this() {
        // set up shared signal handlers for fatal thread-specific signals
        signal(SIGABRT, &signalHandler);
        signal(SIGFPE,  &signalHandler);
        signal(SIGILL,  &signalHandler);
        signal(SIGSEGV, &signalHandler);
        signal(SIGINT, &signalHandler);
    }

    static this() {
        // register our trace handler for each thread
        Runtime.traceHandler = &traceHandler;
    }

    Throwable.TraceInfo traceHandler(void * ptr = null) {
        return new TraceInfo;
    }

    class TraceInfo : Throwable.TraceInfo {
        this() {
            immutable MAXFRAMES = 128;
            void*[MAXFRAMES] callstack;

            numframes = backtrace(callstack.ptr, MAXFRAMES);
            framelist = backtrace_symbols(callstack.ptr, numframes);
        }

        ~this() {
            free(framelist);
        }

        override string toString() const { return null; }   // Why does toString require overriding?

        override int opApply( scope int delegate(ref char[]) dg) {
            return opApply( (ref size_t, ref char[] buf)
                           {
                           return dg( buf );
                           } );
        }


        override int opApply(scope int delegate(ref size_t, ref char[]) dg) {
            // NOTE: The first 5 frames with the current implementation are
            //       inside core.runtime and the object code, so eliminate
            //       these for readability.
            immutable FIRSTFRAME = 5;
            int ret = 0;

            for(int i = FIRSTFRAME; i < numframes; ++i) {
                size_t pos = i - FIRSTFRAME;
                char[] text = framelist[i][0 .. strlen(framelist[i])];

                auto a = text.lastIndexOf('(');
                auto b = text.lastIndexOf('+');

                if (a != -1 && b != -1) {
                    ++a;
                    text = format("%s%s%s", text[0..a], demangle(text[a..b].idup), text[b..$]).dup;
                }

                ret = dg(pos, text);
                if (ret)
                    break;
            }
            return ret;
        }

    private:
        int    numframes; 
        char** framelist;
    }
}
+/

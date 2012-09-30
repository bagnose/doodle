module doodle.tk.color;

struct Color {
    this(in double r, in double g, in double b, in double a) {
        // XXX how to deal with out of range? Clamp/assert
        _r = r;
        _g = g;
        _b = b;
        _a = a;
    }

    // TODO
    // hsv, grey, etc.

    @property double r() const { return _r; }
    @property double g() const { return _g; }
    @property double b() const { return _b; }
    @property double a() const { return _a; }

    private {
        double _r = 0.0, _g = 0.0, _b = 0.0, _a = 1.0;
    }
}

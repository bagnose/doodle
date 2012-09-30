private {
    import std.stdio;
    import std.math;
}

private {
    double start(in double value, in double spacing) {
        real r = floor(value / spacing);
        return r * spacing;
    }
}

void test(double a, double b) {
    double c = start(a, b);
    writefln("%f %f %f", a, b, c);
}

void main(string[] args) {
    test(-100.0, 10.1);
}

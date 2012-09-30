// XXX bob problem, needs it to be like this...
import doodle.tk.geometry;

private {
//import doodle.tk.geometry;
    import std.stdio;
}

void test1() {
    writefln("*** Test1 ***");

    Point p1;
    Point p2 = p1;                              // copy construction
    assert(p1 == p2);                           // equality
    assert(!(p1 != p2));                        // inequality
    p2 = p1;                                    // assignment
    assert(p1 == p2);

    Point p3 = Point(3.0, 5.0);                 // standard constructor
    assert(p3 - p3 == Vector());                // subtraction (point minus point)

    Vector v3 = Vector(3.0, 5.0);
    assert(p3 - v3 == Point());                 // subtraction (point minus vector)

    Point p4 = Point(1.0, 10.0);
    Point p5 = Point(10.0, 1.0);
    assert(minExtents(p4, p5) == Point(1.0, 1.0));     // min extents
    assert(maxExtents(p4, p5) == Point(10.0, 10.0));   // max extents

    writefln("p1: %s", p1);                     // toString
}

void test2() {
    writefln("*** Test2 ***");

    Vector v1;
    Vector v2 = v1;                             // copy construction
    assert(v1 == v2);                           // equality
    assert(!(v1 != v2));                        // inequality
    v2 = v1;                                    // assignment

    Vector v3 = Vector(3.0, 4.0);               // standard construction
    assert(v3 + v3 == Vector(6.0, 8.0));        // addition
    assert(v3 - v3 == Vector());                // subtraction
    assert(-v3 == Vector(-3.0, -4.0));          // negation
    assert(v3.length == 5.0);                   // length
    assert(2.0 * v3 == Vector(6.0, 8.0));       // scalar multiplication
    assert(v3 / 2.0 == Vector(1.5, 2.0));       // scalar division

    writefln("v1: %s", v1);                     // toString
}

void test3() {
    writefln("*** Test3 ***");

    // Horizontal axis
    Line l1 = Line(Point(0.0, 0.0), Vector(1.0, 0.0));
    // Vertical axis
    Line l2 = Line(Point(0.0, 0.0), Vector(0.0, 1.0));

    Point p;
    bool b = intersection(l1, l2, p);
    assert(b);
    assert(p == Point(0.0, 0.0));
}

void test4() {
    writefln("*** Test4 ***");

    Line l1 = Line(Point(-1.0, -1.0), Vector( 1.0, 1.0));
    Line l2 = Line(Point( 1.0, -1.0), Vector(-1.0, 1.0));

    Point p;
    bool b = intersection(l1, l2, p);
    assert(b);
    assert(p == Point(0.0, 0.0));
}

void test5() {
    writefln("*** Test5 ***");

    // Here the segments intersect

    Segment s1 = Segment(Point(2.0, 2.0), Point(4.0, 4.0));
    Segment s2 = Segment(Point(2.0, 4.0), Point(4.0, 2.0));

    Point p;
    bool b = intersection(s1, s2, p);
    assert(b);
    writefln("p: %s", p);
    assert(p == Point(3.0, 3.0));
}

void test6() {
    writefln("*** Test6 ***");

    // Here the lines of the segments intersect but the segments don't

    Segment s1 = Segment(Point(2.0, 2.0), Point(4.0, 4.0));
    Segment s2 = Segment(Point(4.0, 2.0), Point(6.0, 0.0));

    Point p;
    bool b = intersection(s1, s2, p);
    assert(!b);
}

void main(string[] args) {
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
}

module doodle.tk.geometry;

private {
    import std.stdio;
    import std.math;
    import doodle.core.misc;
    import doodle.core.logging;
}

// In doodle x and y increase right/east and up/north respectively.

// TODO explain the strategy for ensuring numerical stability
// and the division of responsibility between users of these
// types and the types themselves.
//
// Explain how numerical instability is handled. The current policy
// is to correct bad user input (eg a gradient with miniscule length) and
// print warnings rather than have assertions that cause crashes.
//
// There are no mutating operations other than opAssign

//
// A location in 2D space
//

struct Point {
    this(in double x, in double y) {
        _x = x;
        _y = y;
    }

    Point opAdd(in Vector v) const {
        return Point(_x + v._x, _y + v._y);
    }

    Point opSub(in Vector v) const {
        return Point(_x - v._x, _y - v._y);
    }

    Vector opSub(in Point p) const {
        return Vector(_x - p._x, _y - p._y);
    }

    string toString() {
        return std.string.format("(%f, %f)", _x, _y);
    }

    @property double x() const { return _x; }
    @property double y() const { return _y; }

    private {
        double _x = 0.0, _y = 0.0;
    }
}

Point minExtents(in Point a, in Point b) {
    return Point(min(a.x, b.x), min(a.y, b.y));
}

Point maxExtents(in Point a, in Point b) {
    return Point(max(a.x, b.x), max(a.y, b.y));
}

//
// The displacement between two locations in 2D space
//

struct Vector {
    this(in double x, in double y) {
        _x = x;
        _y = y;
    }

    Vector opAdd(in Vector v) const {
        return Vector(_x + v._x, _y + v._y);
    }

    Vector opSub(in Vector v) const {
        return Vector(_x - v._x, _y - v._y);
    }

    Vector opNeg() const {
        return Vector(-_x, -_y);
    }

    Vector opMul_r(in double d) const {
        assert(!isnan(d));
        return Vector(d * _x, d * _y);
    }

    Vector opDiv(in double d) const {
        assert(!isnan(d));
        return Vector(_x / d, _y / d);
    }

    @property double length() const {
        return sqrt(_x * _x + _y * _y);
    }

    string toString() {
        return std.string.format("[%f, %f]", _x, _y);
    }

    @property double x() const { return _x; }
    @property double y() const { return _y; }

    private {
        double _x = 0.0, _y = 0.0;
    }
}

/*
Vector normal(in Vector v) {
    double l = v.length;

    if (l < 1e-9) {         // TODO consolidate numerical stability constants
        writefln("Warning: normalising tiny vector. Length: %f", l);
        return Vector(1.0, 0.0);
    }
    else {
        return v / l;
    }
}
*/

//
// A rectangle in 2D space.
// Internally represented by:
//   a point defining the bottom left corner
//   a vector defining the displacement to the upper right corner
//

struct Rectangle {
    /*
       static Rectangle from_arbitrary_corners(in Point corner1, in Point corner) {
       }
     */

    this(in Point position, in Vector size) {
        this(position.x, position.y, size.x, size.y);
    }

    this(in Point corner1, in Point corner) {
        this(corner1.x, corner1.y, corner.x - corner1.x, corner.y - corner1.y);
    }

    @property double x0() const { return _position.x; }
    @property double y0() const { return _position.y; }
    @property double w()  const { return _size.x; }
    @property double h()  const { return _size.y; }
    @property double x1() const { return x0 + w; }
    @property double y1() const { return y0 + h; }

    alias position corner0;
    @property Point position() const { return _position; }

    @property Vector size() const { return _size; }

    @property Point corner1() const { return _position + _size; }

    @property bool valid() const { return _size.x > 0.0 && _size.y > 0.0; }

    @property bool invalid() const { return !valid(); }

    @property double area() const { return _size.x * _size.y; }

    // Intersection
    Rectangle opAnd(in Rectangle r) const {
        if (invalid() || r.invalid()) {
            return Rectangle();
        }
        else {
            Point max = minExtents(corner1(), r.corner1());
            Point min = maxExtents(corner0(), r.corner0());

            if (max.x < min.x || max.y < min.y) {
                return Rectangle();
            }
            else {
                return Rectangle(min, max);
            }
        }
    }

    // Union
    Rectangle opOr(in Rectangle r) const {
        if (invalid()) {
            return r;
        }
        else if (r.invalid()) {
            return this;
        }
        else {
            return Rectangle(minExtents(corner0(), r.corner0()),
                             maxExtents(corner1(), r.corner1()));
        }
    }

    bool contains(in Rectangle r) const {
        if (r.valid) {
            return x0 <= r.x0 && y0 <= r.y0 && x1 >= r.x1 && y1 >= r.y1;
        }
        else {
            return valid;
        }
    }

    //

    // FIXME this method is all about pixels. Not sure it belongs in
    // this file, let alone this class.
    void getQuantised(out int x, out int y, out int w, out int h) const {
        x = cast(int)floor(_position.x);
        y = cast(int)floor(_position.y);
        w = cast(int)ceil(_position.x + _size.x) - x;
        h = cast(int)ceil(_position.y + _size.y) - y;
    }

    //

    @property Point centre() const { return _position + _size / 2.0; }

    string toString() {
        return std.string.format("{%s, %s}", _position, _size);
    }

    private {
        this(double x, double y, double w, double h) {
            if (w < 0.0) { x += w; w = -w; }
            if (h < 0.0) { y += h; h = -h; }
            _position = Point(x, y);
            _size = Vector(w, h);
        }

        Point _position;
        Vector _size;
    }
}

Rectangle growCentre(in Rectangle r, in Vector amount) {
    return Rectangle(r.x0 - amount.x / 2, r.y0 - amount.y / 2, r.w + amount.x, r.h + amount.y);
}

Rectangle growCentre(in Rectangle r, in double amount) {
    return Rectangle(r.x0 - amount / 2, r.y0 - amount / 2, r.w + amount, r.h + amount);
}

// TODO review these functions.
// Want a clear and simple set.

/+
Rectangle move(in Rectangle r, in Vector displacement) {
    return Rectangle(r.position + displacement, r.size);
}

Rectangle reposition(in Rectangle r, in Point newPosition) {
    return Rectangle(newPosition, r.size);
}

Rectangle resize(in Rectangle r, in Vector new_size) {
    return Rectangle(r.position, new_size);
}

// Operations about the bottom left corner

Rectangle expand(in Rectangle r, in Vector expand_amount) {
    return Rectangle(r.position, r.size + expand_amount);
}

Rectangle shrink(in Rectangle r, in Vector shrink_amount) {
    return Rectangle(r.position, r.size - shrink_amount);
}
+/

// Operations about the centre

/+
Rectangle feather(in Rectangle r, double amount) {          // feather isn't the right name
    assert(amount >= 0.0);
    assert(!isnan(amount));
    return Rectangle(Point(r.position.x - amount, r.position.y - amount),
                     Vector(r.size.x + 2.0 * amount, r.size.y + 2.0 * amount));
}
+/

private {
    // This function computes the intersection of two lines.
    // The lines are defined by a start point and an end point, however they
    // notionally extend infinitely in each direction.
    // The out parameters specify the fraction along the line-segment at which
    // intersection occurred.
    //
    // This is a commmon building block for computing intersection between lines, segments,
    // rectangles, etc.
    //
    // The function returns false if the lines are parallel or nearly so.
    //
    // Influenced by http://ozviz.wasp.uwa.edu.au/~pbourke/geometry/lineline2d/
    bool computeIntersection(in Point pa1, in Point pa2, out double ua,
                             in Point pb1, in Point pb2, out double ub) {
        double den = (pb2.y - pb1.y) * (pa2.x - pa1.x) - (pb2.x - pb1.x) * (pa2.y - pa1.y);

        if (abs(den) < 1e-9) {          // TODO consolidate constants used for numerical stability
            // Lines are parallel or nearly so
            warning("Warning, parallel lines!");
            return false;
        }
        else {
            // It will be safe to divide by den
            double numA = (pb2.x - pb1.x) * (pa1.y - pb1.y) - (pb2.y - pb1.y) * (pa1.x - pb1.x);
            double numB = (pa2.x - pa1.x) * (pa1.y - pb1.y) - (pa2.y - pa1.y) * (pa1.x - pb1.x);

            ua = numA / den;
            ub = numB / den;

            return true;
        }
    }

    /+
        double compute_angle(in Point p1, in Point p2) {
        }
    +/
}

//
// A line (notionally infinitely extending in both directions) in 2D space.
// Internally represented by:
//   a point at an arbitrary location along the line
//   a vector defining the gradient of the line
//

struct Line {
    this(in Point p, in Vector g) {
        _point = p;
        _gradient = g;
        // FIXME should we normalise (make unit length) the gradient?
        assert(_gradient.length > 1e-6);        // FIXME how to best deal with this
    }

    this(in Point a, in Point b) {
        _point = a;
        _gradient = b - a;
        assert(_gradient.length > 1e-6);        // FIXME as above
    }

    @property Point point() const { return _point; }
    @property Vector gradient() const { return _gradient; }

    string toString() {
        return std.string.format("{%s %s}", _point, _gradient);
    }

    private {
        Point  _point;           // Arbitrary point along line
        Vector _gradient;
    }
}

// Calculate the point "p" where lines "a" and "b" intersect.
// Returns false if lines are parallel or too close for numerical stability
bool intersection(in Line a, in Line b, out Point p) {
    Point  pa = a.point;
    Vector va = a.gradient;
    double ua;

    Point  pb = b.point;
    Vector vb = b.gradient;
    double ub;

    if (computeIntersection(pa, pa + va, ua, pb, pb + vb, ub)) {
        // We could just have easily evaluated for line b...
        p = pa + ua * va;
        // p = pb + ub * vb;
        return true;
    }
    else {
        return false;
    }
}

//
// A line segment (has a beginning and an end) in 2D space.
//

struct Segment {
    this(in Point a, in Point b) {
        _begin = a;
        _end = b;
    }

    @property Point begin() const { return _begin; }
    @property Point end() const { return _end; }

    string toString() {
        return std.string.format("{%s %s}", _begin, _end);
    }

    private {
        Point _begin, _end;
    }
}

/*
Segment reverse(in Segment s) {
    return Segment(s.end, s.begin);
}
*/

bool intersection(in Segment a, in Segment b, out Point p) {
    Point pa1 = a.begin;
    Point pa2 = a.end;
    double ua;

    Point pb1 = b.begin;
    Point pb2 = b.end;
    double ub;

    if (computeIntersection(pa1, pa2, ua, pb1, pb2, ub)) {
        if (ua >= 0.0 && ua <= 1.0 &&     // inside of segment a
            ub >= 0.0 && ub <= 1.0) {     // inside of segment b
            // We could just as easily evaluated for line b...
            p = pa1 + ua * (pa2 - pa1);
            // p = pa2 + ub * (pb2 - pb1);
            return true;
        }
        else {
            return false;
        }
    }
    else {
        return false;
    }
}

bool intersection(in Segment a, in Line b, out Point p) {
    Point pa1 = a.begin;
    Point pa2 = a.end;
    double ua;

    Point pb = b.point;
    Vector vb = b.gradient;
    double ub;

    if (computeIntersection(pa1, pa2, ua, pb, pb + vb, ub)) {
        if (ua >= 0.0 && ua <= 1.0) {   // inside of segment
            // We could just as easily evaluated for line b...
            p = pa1 + ua * (pa2 - pa1);
            // p = pb + ub * vb;
            return true;
        }
        else {
            return false;
        }
    }
    else {
        return false;
    }
}

bool intersection(in Line a, in Segment b, out Point p) {
    // Equivalent to intersection of segment and line. Just reverse the args.
    return intersection(b, a, p);
}

/+
bool intersection(in Line l, in Rectangle r, out Point p1, out Point p2) {
    // TODO
    return false;
}

bool intersection(in Segment s, in Rectangle r, out Point p1, out Point p2) {
    // TODO
    return false;
}
+/

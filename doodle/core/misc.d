module doodle.core.misc;

// Basic routines.
// Note, most of these are probably provided by phobos.

double min(in double a, in double b) {
    return a < b ? a : b;
}

double max(in double a, in double b) {
    return a > b ? a : b;
}

double clamp(in double v, in double min, in double max) {
    assert(min < max);

    if (v < min) { return min; }
    else if (v > max) { return max; }
    else { return v; }
}

// wrap?

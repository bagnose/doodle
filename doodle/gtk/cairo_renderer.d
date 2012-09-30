module doodle.gtk.cairo_renderer;

public {
    import doodle.tk.renderer;
    import cairo.Context;
}

final class CairoRenderer : Renderer {
    this(Context cr) {
        assert(cr);
        _cr = cr;
    }

    // Drawing overrides:

    void setLineStyle(LineStyle style) {
        switch (style) {
        case LineStyle.SOLID:
            _cr.setDash([ ], 0.0);
            break;
        case LineStyle.DASHED:
            _cr.setDash([ 4.0, 4.0 ], 0.0);
            break;
        case LineStyle.DOTTED:
            _cr.setDash([ 1.0, 4.0 ], 0.0);
            break;
        default:
            assert(0);
        }
    }

    void setLineWidth(in double width) { _cr.setLineWidth(width); }

    void setColor(in Color color) { _cr.setSourceRgba(color.r, color.g, color.b, color.a); }

    void translate(in Point p) { _cr.translate(p.x, p.y); }
    void scale(in double s) { _cr.scale(s, s); }

    void pushState() { _cr.save(); }
    void popState() { _cr.restore(); }

    void drawRectangle(in Rectangle rectangle, bool fill = false) {
        _cr.rectangle(rectangle.position.x, rectangle.position.y,
                      rectangle.size.x, rectangle.size.y);
        if (fill) { _cr.fill(); } else { _cr.stroke(); }
    }

    void drawEllipse(in Rectangle rectangle, bool fill = false) {
        // NYI
    }

    void drawSegment(in Segment segment) {
        _cr.moveTo(segment.begin.x, segment.begin.y);
        _cr.lineTo(segment.end.x, segment.end.y);
        _cr.stroke();
    }

    void drawHLine(in double y, in double x0, in double x1) {
        _cr.moveTo(x0, y);
        _cr.lineTo(x1, y);
        _cr.stroke();
    }

    void drawVLine(in double x, in double y0, in double y1) {
        _cr.moveTo(x, y0);
        _cr.lineTo(x, y1);
        _cr.stroke();
    }

    void drawPoly(in Point[] points, bool fill = false) {
        assert(points.length >= 2);
        foreach(i, p; points) {
            if (i == 0) { _cr.moveTo(p.x, p.y); }
            else { _cr.lineTo(p.x, p.y); }
        }
        if (fill) { _cr.fill(); } else { _cr.stroke(); }
    }

    void setFontFace(in FontFace face) {
        // NYI
    }

    void setFontSize(in double size) {
        // NYI
    }

    void drawText(in string text) {
        // NYI
    }

    void measureText(in string text, out Rectangle logicalBounds, out Rectangle totalBounds) const {
        // NYI
    }

    private {
        Context _cr;
    }
}

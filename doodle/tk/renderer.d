module doodle.tk.renderer;

public {
    import doodle.tk.geometry;
    import doodle.tk.color;
}

interface Renderer {
    enum LineStyle {
        SOLID,
        DASHED,
        DOTTED
    }

    enum FontFace {
        NORMAL
    }

    // Low-level state manipulation

    void setLineStyle(LineStyle style);
    void setLineWidth(in double width);
    void setColor(in Color color);

    void translate(in Point p);
    void scale(in double s);

    void pushState();           // Copies all of current state
    void popState();            // Restores all of previous state

    // High-level drawing routines

    void drawRectangle(in Rectangle rectangle, bool fill);
    void drawEllipse(in Rectangle rectangle, bool fill);
    void drawSegment(in Segment segment);
    void drawHLine(in double y, in double x0, in double x1);
    void drawVLine(in double x, in double y0, in double y1);
    void drawPoly(in Point[] points, bool fill);

    // Text routines

    void setFontFace(in FontFace face);
    void setFontSize(in double size);
    void drawText(in string text);

    void measureText(in string text, out Rectangle logicalBounds, out Rectangle totalBounds) const;
}

module doodle.dia.icanvas;

public {
    import doodle.tk.geometry;
    import doodle.tk.events;
    import doodle.tk.renderer;
    import doodle.tk.screen_model;
}

private {
    import std.typecons;
}

enum Cursor {
    DEFAULT,
    HAND,
    CROSSHAIR,
    PENCIL
}

interface IDamageable {
    void damageModel(in Rectangle area);
    void damageScreen(in Rectangle area);
}

interface IViewport : IDamageable {
    void zoomRelative(in double factor, in Point screenDatum);
    void panRelative(in Vector screenDisplacement);
    void setCursor(in Cursor cursor);
}

/*
final class Damage {
    void increase(in Rectangle additional) { _rectangle = _rectangle | additional; }
    Rectangle rectangle() const { return _rectangle; }
    private Rectangle _rectangle;
}
*/

interface IEventHandler {
    bool handleButtonPress(scope IViewport viewport, in ButtonEvent event);
    bool handleButtonRelease(scope IViewport viewport, in ButtonEvent event);
    bool handleMotion(scope IViewport viewport, in MotionEvent event);
    bool handleScroll(scope IViewport viewport, in ScrollEvent event);
    bool handleEnter(scope IViewport viewport, in CrossingEvent event);
    bool handleLeave(scope IViewport viewport, in CrossingEvent event);
    bool handleKeyPress(scope IViewport viewport, in KeyEvent event);
    bool handleKeyRelease(scope IViewport viewport, in KeyEvent event);

    // XXX Still not sure about these:
    //bool handleFocusIn(scope IViewport viewport, in FocusEvent event);
    //bool handleFocusOut(scope IViewport viewport, in FocusEvent event);
}

interface IGrid {
    void zoomChanged(in double zoom);

}

interface IPage {
}

abstract class Layer {
    this(in string name) {
        _name = name;
    }

    @property string name() const { return _name; }

    @property Rectangle bounds() const;

    //bool snap(in Point a, out Point b) const;

    void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
              in Rectangle modelDamage, scope Renderer modelRenderer,
              in ScreenModel screenModel) const;

    private {
        immutable string _name;
    }
}

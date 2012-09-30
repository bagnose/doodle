module doodle.dia.tool;

public {
    import cairo.Context;
    import doodle.dia.icanvas;
    import doodle.tk.events;
}

//

abstract class Tool {
    this (in string name) {
        _name = name;
    }

    @property string name() const { return _name; }

    bool handleButtonPress(scope IViewport viewport, in ButtonEvent event) { return false; }
    bool handleButtonRelease(scope IViewport viewport, in ButtonEvent event) { return false; }
    bool handleMotion(scope IViewport viewport, in MotionEvent event) { return false; }
    bool handleScroll(scope IViewport viewport, in ScrollEvent event) { return false; }
    bool handleEnter(scope IViewport viewport, in CrossingEvent event) { return false; }
    bool handleLeave(scope IViewport viewport, in CrossingEvent event) { return false; }
    bool handleKeyPress(scope IViewport viewport, in KeyEvent event) { return false; }
    bool handleKeyRelease(scope IViewport viewport, in KeyEvent event) { return false; }
    //bool handleFocusIn(scope IViewport viewport, FocusEvent event) { return false; }
    //bool handleFocusOut(scope IViewport viewport, FocusEvent event) { return false; }

    void draw(in Rectangle screenDamage, scope Renderer screenRenderer) const { }

    private {
        immutable string _name;
    }
}

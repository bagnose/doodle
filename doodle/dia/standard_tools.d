module doodle.dia.standard_tools;

public {
    import doodle.dia.tool;
}

private {
    import gdk.Keysyms;
}

final class PanTool : Tool {
    this() {
        super("Pan");
    }

    override bool handleButtonPress(scope IViewport viewport, in ButtonEvent event) {
        if (event.buttonName == ButtonName.MIDDLE) {
            _lastPosition = event.screenPoint;
            return true;
        }
        else {
            return false;
        }
    }

    override bool handleMotion(scope IViewport viewport, in MotionEvent event) {
        if (event.mask.isSet(Modifier.MIDDLE_BUTTON)) {
            viewport.panRelative(_lastPosition - event.screenPoint);
            _lastPosition = event.screenPoint;

            return true;
        }
        else {
            return false;
        }
    }

    override bool handleScroll(scope IViewport viewport, in ScrollEvent event) {
        if (event.mask.isUnset(Modifier.MIDDLE_BUTTON)) {
            Vector delta;

            switch (event.scrollDirection) {
            case ScrollDirection.UP:
                delta = event.mask.isSet(Modifier.SHIFT) ? Vector(-SCROLL_AMOUNT, 0.0) : Vector(0.0, SCROLL_AMOUNT);
                break;
            case ScrollDirection.DOWN:
                delta = event.mask.isSet(Modifier.SHIFT) ? Vector(SCROLL_AMOUNT, 0.0) : Vector(0.0, -SCROLL_AMOUNT);
                break;
            case ScrollDirection.LEFT:
                delta = Vector(-SCROLL_AMOUNT, 0.0);
                break;
            case ScrollDirection.RIGHT:
                delta = Vector(SCROLL_AMOUNT, 0.0);
                break;
            default:
                assert(0);
            }

            viewport.panRelative(delta);
        }

        return true;
    }

    override bool handleKeyPress(scope IViewport viewport, in KeyEvent event) {
        // Respond to arrow keys and pg-up/pg-down

        switch (event.value) {
        case GdkKeysyms.GDK_Up:
            viewport.panRelative(Vector(0.0, ARROW_AMOUNT));
            return true;
        case GdkKeysyms.GDK_Right:
            viewport.panRelative(Vector(ARROW_AMOUNT, 0.0));
            return true;
        case GdkKeysyms.GDK_Left:
            viewport.panRelative(Vector(-ARROW_AMOUNT, 0.0));
            return true;
        case GdkKeysyms.GDK_Down:
            viewport.panRelative(Vector(0.0, -ARROW_AMOUNT));
            return true;
        case GdkKeysyms.GDK_Page_Up:
            viewport.panRelative(Vector(0.0, PAGE_AMOUNT));
            return true;
        case GdkKeysyms.GDK_Page_Down:
            viewport.panRelative(Vector(0.0, -PAGE_AMOUNT));
            return true;
        default:
            // Just a key we don't handle
            return false;
        }
    }

    private {
        Point _lastPosition;
        static immutable SCROLL_AMOUNT = 60.0;
        static immutable ARROW_AMOUNT = 30.0;
        static immutable PAGE_AMOUNT = 240.0;
    }
}

final class ZoomTool : Tool {
    this() {
        super("Zoom");
    }

    override bool handleScroll(scope IViewport viewport, in ScrollEvent event) {
        if (event.mask.isSet(Modifier.CONTROL)) {
            if (event.scrollDirection == ScrollDirection.DOWN) {
                viewport.zoomRelative(1.0 / ZOOM_FACTOR, event.screenPoint);
                return true;
            }
            else if (event.scrollDirection == ScrollDirection.UP) {
                viewport.zoomRelative(ZOOM_FACTOR, event.screenPoint);
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

    private {
        static immutable ZOOM_FACTOR = 2^^0.5;
    }
}

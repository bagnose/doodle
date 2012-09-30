module doodle.fig.select_tool;

public {
    import doodle.dia.tool;
}

final class SelectTool : Tool {
    this() {
        super("Select");
    }

    override bool handleButtonPress(scope IViewport viewport, in ButtonEvent event) {
        if (event.buttonName == ButtonName.LEFT) {
            _active = true;
            _anchorPoint = _currentPoint = event.screenPoint;
            viewport.setCursor(Cursor.HAND);
            return true;
        }
        else {
            return false;
        }
    }

    override bool handleButtonRelease(scope IViewport viewport, in ButtonEvent event) {
        if (event.buttonName == ButtonName.LEFT && _active) {
            _active = false;
            viewport.damageScreen(growCentre(Rectangle(_anchorPoint, _currentPoint), LINE_WIDTH));
            viewport.setCursor(Cursor.DEFAULT);
            return true;
        }
        else {
            return false;
        }
    }

    override bool handleMotion(scope IViewport viewport, in MotionEvent event) {
        if (_active) {
            viewport.damageScreen(growCentre(Rectangle(_anchorPoint, _currentPoint), LINE_WIDTH));
            _currentPoint = event.screenPoint;
            viewport.damageScreen(growCentre(Rectangle(_anchorPoint, _currentPoint), LINE_WIDTH));
        }

        return false;
    }

    override void draw(in Rectangle screenDamage, scope Renderer screenRenderer) const {
        if (_active) {
            screenRenderer.pushState(); {
                screenRenderer.setLineStyle(Renderer.LineStyle.DASHED);
                screenRenderer.setLineWidth(LINE_WIDTH);
                screenRenderer.setColor(Color(0.0, 0.0, 0.5, 1.0));
                screenRenderer.drawRectangle(Rectangle(_currentPoint, _anchorPoint), false);
            } screenRenderer.popState();
        }
    }

    private {
        bool _active;
        Point _currentPoint;
        Point _anchorPoint;
        static immutable double LINE_WIDTH = 1.0;
    }
}

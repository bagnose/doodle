module doodle.fig.tools;

private {
    import doodle.dia.tool;
    import doodle.fig.diagram_layer;
}

final class CreateRectangleTool : Tool {
    this(IDiagram diagram) {
        super("Create Rectangle");
        _diagram = diagram;
    }

    // Tool overrides:

    override bool handleButtonPress(scope IViewport viewport, in ButtonEvent event) {
        if (event.buttonName == ButtonName.LEFT) {
            return true;
        }
        else {
            return false;
        }
    }

    override bool handleButtonRelease(scope IViewport viewport, in ButtonEvent event) {
        return true;
    }

    override bool handleMotion(scope IViewport viewport, in MotionEvent event) {
        return true;
    }

    private {
        IDiagram _diagram;
    }
}

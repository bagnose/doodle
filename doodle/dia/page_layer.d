module doodle.dia.page_layer;

public {
    import doodle.dia.icanvas;
}

private {
}

class PageLayer : Layer, IPage {
    this(in string name = "Page") {
        super(name);
        _pageGeometry = Rectangle(Point(), Vector(210.0, 297.0));
        //_pageGeometry = Rectangle(Point(), Vector(100.0, 100.0));
    }

    // Layer overrides:

    override Rectangle bounds() const {
        return _pageGeometry;
    }

    override void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
                       in Rectangle modelDamage, scope Renderer modelRenderer,
                       in ScreenModel screenModel) const {
        // Make the paper white, with a border

        modelRenderer.pushState(); {
            modelRenderer.setColor(Color(0.0, 0.0, 0.0, 1.0));
            modelRenderer.drawRectangle(_pageGeometry, false);
        } modelRenderer.popState();

        modelRenderer.pushState(); {
            modelRenderer.setColor(Color(1.0, 1.0, 1.0, 1.0));
            modelRenderer.drawRectangle(_pageGeometry, true);
        } modelRenderer.popState();
    }

    // IPage overrides:

    private {
        Rectangle _pageGeometry;
    }
}

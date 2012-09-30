module doodle.dia.grid_layer;

public {
    import doodle.dia.icanvas;
}

private {
    import std.math;
    import std.stdio;
    import std.array;

    import doodle.core.logging;
}

// Draw a grid.
// zoom -> pixels / millimetre
// Grid lines must have a maximum density
// 

class GridLayer : Layer, IGrid {
    this(in string name = "Grid") {
        super(name);
        _spacingValid = false;
    }

    // Layer overrides:

    override Rectangle bounds() const {
        // We don't require any geometry
        return Rectangle();
    }

    override void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
                       in Rectangle modelDamage, scope Renderer modelRenderer,
                       in ScreenModel screenModel) const {
        assert(_spacingValid);

        const z = screenModel.zoom;
        const lineWidthModel = LINE_WIDTH_SCREEN / z;

        modelRenderer.pushState(); {
            modelRenderer.setColor(doodle.tk.color.Color(0.0, 0.0, 0.7, 1.0));
            modelRenderer.setLineWidth(lineWidthModel);

            auto x = roundDownSpacing(modelDamage.corner0.x);

            for (;;) {
                modelRenderer.drawVLine(x, modelDamage.corner0.y, modelDamage.corner1.y);
                x += _spacing;
                if (x > modelDamage.corner1.x) break;
            }

            auto y = roundDownSpacing(modelDamage.corner0.y);

            for (;;) {
                modelRenderer.drawHLine(y, modelDamage.corner0.x, modelDamage.corner1.x);
                y += _spacing;
                if (y > modelDamage.corner1.y) break;
            }
        } modelRenderer.popState();
    }

    // IGrid overrides:

    override void zoomChanged(in double zoom) {
        foreach (s; SPACINGS) {
            _spacing = s;
            double pixels = zoom * _spacing;
            if (pixels > MIN_SPACING) { break; }
        }
        _spacingValid = true;
    }

    private {
        double roundDownSpacing(in double value) const {
            return _spacing * floor(value / _spacing);
        }

        bool _spacingValid;
        double _spacing;        // model spacing

        immutable double LINE_WIDTH_SCREEN = 0.25;
        immutable double MIN_SPACING = 40.0;      // pixels
        immutable double[] SPACINGS =    // millimetres
            [
            5.0,
            10.0,
            20.0,
            50.0
            ];
    }
}

module doodle.fig.diagram_layer;

public {
    import doodle.dia.icanvas;
    import doodle.fig.diagram_elements;
    import std.array;
}

class DiagramLayer : Layer, IDiagram {
    this(in string name = "Diagram") {
        super(name);
    }

    // IDiagram overrides:

    void add(DiagramElement element) {
        _elements ~= element;
    }

    // Layer overrides:

    override Rectangle bounds() const {
        // Take the union of all diagram element bounds
        /*
        Rectangle bounds;
        foreach (element; _elements) { bounds = bounds | element.bounds; }
        */
        return Rectangle();
    }

    override void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
                       in Rectangle modelDamage, scope Renderer modelRenderer,
                       in ScreenModel screenModel) const {
        /*
        foreach (e; _elements) {
            if ((e.bounds & modelDamage).valid) {       // FIXME if (intersects(e.bounds, modelDamage))
                e.draw(modelDamage, modelRenderer);
            }
        }
        */
    }

    private {
        // Root elements in z-buffer order, ie we draw in forward
        // order thru the array
        DiagramElement[] _elements;
    }
}

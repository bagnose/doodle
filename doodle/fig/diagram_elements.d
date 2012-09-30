module doodle.fig.diagram_elements;

public {
    import doodle.tk.geometry;
}

private {
    import doodle.tk.renderer;
}

interface IDiagram {
    void add(DiagramElement element);
}

abstract class DiagramElement {
    @property Rectangle bounds() const;

    void draw(in Rectangle damage, scope Renderer cr) const;

    private {
        GraphElement _container;
    }
}

abstract class SemanticModelBridge {
}

final class SimpleSemanticModelElement : SemanticModelBridge {
    private {
        string _typeInfo;
    }
}

abstract class GraphElement : DiagramElement {
    // Link to model via bridge goes here
    private {
        SemanticModelBridge _modelBridge;
        GraphConnector[] _anchorages;
        DiagramElement[] _containeds;
    }
}

class GraphConnector {
    private {
        GraphElement _graphElement;
        GraphEdge[] _graphEdges;
    }
}

final class GraphNode : GraphElement {
    @property override Rectangle bounds() const { return _bounds; }

    override void draw(in Rectangle damage, scope Renderer cr) const {
    }

    private {
        Rectangle _bounds;
    }
}

final class GraphEdge : GraphElement {
    @property override Rectangle bounds() const { return _bounds; }

    override void draw(in Rectangle damage, scope Renderer cr) const {
    }

    private {
        GraphConnector[2] _anchors;
        Point[] _waypoints;
        Rectangle _bounds;
    }
}

abstract class LeafElement : DiagramElement {
}

class TextElement : LeafElement {
    @property override Rectangle bounds() const { return _bounds; }

    override void draw(in Rectangle damage, scope Renderer cr) const {
    }

    private {
        Rectangle _bounds;
    }
}

abstract class GraphicPrimitive : LeafElement {
}

class PolylinePrimitive : GraphicPrimitive {
    @property override Rectangle bounds() const { return _bounds; }

    override void draw(in Rectangle damage, scope Renderer cr) const {
    }

    private {
        Point[] _waypoints;
        Rectangle _bounds;
    }
}

final class RectanglePrimitive : GraphicPrimitive {
    @property override Rectangle bounds() const { return _bounds; }

    override void draw(in Rectangle damage, scope Renderer drawable) const {
        drawable.drawRectangle(bounds, false);
    }

    private {
        Rectangle _bounds;
    }
}

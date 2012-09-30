module doodle.fig.network;

public {
    import doodle.fig.diagram_elements;
}

enum EdgeEnd {
    Source,
    Target
};

interface INetworkObserver {
    // Node changes

    void nodeAdded(GraphNode node,
                   GraphElement container);
    void nodeChanged(GraphNode node);
    void nodeRelocated(GraphNode node,
                       GraphElement container);
    void nodeRemoved(GraphNode node,
                     GraphElement container);

    // Edge changes

    void edgeAdded(GraphEdge edge);
    void edgeChanged(GraphEdge edge);
    void edgeRerouted();
    void edgeRemoved();
}

interface INetwork {
    void addObserver(INetworkObserver observer);
    void removeObserver(INetworkObserver observer);

    //
    // Interrogation:
    //

    GraphNode[] getRootNodes();

    // Inquire whether in principle a node of node_type
    // can be added at the given point, possibly nested
    // within the nest node. The nest can be null.
    bool canAdd(string node_type,
                Point point,           // necessary?
                GraphNode nest);

    bool canRelocate(GraphNode node);

    bool canRemove(GraphNode node);

    // Inquire whether in principle the source element can
    // be connected to the target element using
    // an edge of edge_type. This might return true even
    // though the real operation would fail due to deeper checking.
    bool canConnect(char[] edge_type,
                    GraphElement sourceElement, Point sourcePoint,
                    GraphElement targetElement, Point targetPoint);

    // Inquire whether in principle a given end of an existing edge
    // can be rerouted from old_element to new_element at new_point.
    // old_element and new_element may be the same element.
    bool canReroute(GraphEdge edge, EdgeEnd end,
                    GraphElement oldElement,
                    GraphElement newElement, Point newPoint);

    bool canDisconnect(GraphEdge edge);

    //
    // Manipulation:
    //

    // Attempt to really add a node...
    GraphNode add(char[] node_type, /* initial properties, */
                  Point point,
                  GraphNode nest);

    void relocate(GraphNode node,
                  GraphElement oldContainer,
                  GraphElement newContainer, Point newPoint);

    // Attempt to really remove a node
    void remove(GraphNode node);

    // Attempt to really connect the source element to the target element
    // using an edge of the given type with the given initial properties.
    GraphEdge connect(string edge_type, /* initial properties, */
                      GraphElement sourceElement, Point sourcePoint,
                      GraphElement targetElement, Point targetPoint);

    // Attempt to really reroute..
    void reroute(GraphEdge edge, EdgeEnd end,
                 GraphElement oldElement,
                 GraphElement newElement, Point newPoint);

    // Attempt to really remove an edge...
    void disconnect(GraphEdge edge);
}

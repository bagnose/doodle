module doodle.dia.layer_stack;

public {
    import doodle.dia.icanvas;
}

final class LayerStack {
    this(Layer[] layers) {
        _layers = layers.dup;
    }

    @property Rectangle bounds() const {
        // Take the union of all layer bounds
        Rectangle bounds;
        foreach (layer; _layers) { bounds = bounds | layer.bounds; }
        return bounds;
    }

    void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
              in Rectangle modelDamage,  scope Renderer modelRenderer,
              in ScreenModel screenModel) const {
        foreach(layer; _layers) {
            layer.draw(screenDamage, screenRenderer, modelDamage, modelRenderer, screenModel);
        }
    }

    private {
        Layer[] _layers;
    }
}

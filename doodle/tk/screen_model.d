module doodle.tk.screen_model;

public {
    import doodle.tk.geometry;
}

private {
    import doodle.core.misc;
}

/*
interface IScreenModelObserver {
    void screenDamaged(in Rectangle screenDamage);
    void cursorChanged(in Cursor cursor);
}
*/

// This class manages the relationship between screen space and model space.
// Screen is defined as the current window/viewport into the model
// It provides convenient high-level operations.
//
// x and y run right and up respectively for screen and model space

class ScreenModel {
    /*
    void damageModel
    */


    this(in double zoom, in Rectangle canvasBoundsModel, in Rectangle viewBoundsScreen) {
        _zoom = zoom;
        _viewBoundsScreen = viewBoundsScreen;
        _canvasBoundsModel = canvasBoundsModel;

        // Choose the centre of the canvas as the centre of the view
        _viewCentreModel = _canvasBoundsModel.centre;
    }

    void setViewBoundsScreen(in Rectangle viewBoundsScreen) { _viewBoundsScreen = viewBoundsScreen; }
    void consolidateCanvasBounds(in Rectangle requiredCanvasBounds) { _canvasBoundsModel = screenToModel(_viewBoundsScreen) | requiredCanvasBounds; }
    void canvasAccommodate(in Rectangle bounds) { _canvasBoundsModel = _canvasBoundsModel | bounds; }

    void zoomRelative(in double factor, in Point screenDatum) {
        // Work out screen distance from current centre to datum,
        // Do the zoom, then work out the new centre that keeps the
        // screen distance the same

        Point oldModelDatum = screenToModel(screenDatum);
        Vector screenDistance = modelToScreen(oldModelDatum - _viewCentreModel);
        _zoom = clampZoom(zoom * factor);
        _viewCentreModel = oldModelDatum - screenToModel(screenDistance);
    }

    void panRelativeScreen(in Vector screenDisplacement) { _viewCentreModel = _viewCentreModel + screenToModel(screenDisplacement); }
    void panRelativeModel(in Vector modelDisplacement) { _viewCentreModel = _viewCentreModel + modelDisplacement; }

    // For userZoom 1.0 -> 100% means the presentation on the screen is one-to-one with real-life
    double userZoom(in double pixelsPerMillimetre) const { return _zoom / pixelsPerMillimetre; }
    @property double zoom() const { return _zoom; }
    @property Rectangle viewBoundsScreen() const { return _viewBoundsScreen; }
    @property Rectangle viewBoundsModel() const { return screenToModel(_viewBoundsScreen); }
    @property Rectangle canvasBoundsModel() const { return _canvasBoundsModel; }
    @property Rectangle canvasBoundsScreen() const { return modelToScreen(_canvasBoundsModel); }

    Point modelToScreen(in Point model) const { return _viewBoundsScreen.centre + _zoom * (model - _viewCentreModel); }
    Point screenToModel(in Point screen) const { return _viewCentreModel + (screen - _viewBoundsScreen.centre) / _zoom; }
    Vector modelToScreen(in Vector model) const { return _zoom * model; }
    Vector screenToModel(in Vector screen) const { return screen / _zoom; }
    Rectangle modelToScreen(in Rectangle model) const { return Rectangle(modelToScreen(model.position), modelToScreen(model.size)); }
    Rectangle screenToModel(in Rectangle model) const { return Rectangle(screenToModel(model.position), screenToModel(model.size)); }

    private {
        static double clampZoom(in double zoom) { return clamp(zoom, 1e-1, 1e2); }

        // Screen units are pixels
        // Model units are millimetres
        double    _zoom;                // pixels-per-millimetre
        Rectangle _viewBoundsScreen;    // bounds of the viewport in screen space
        Point     _viewCentreModel;     // where in the model is the centre of our screen
        Rectangle _canvasBoundsModel;   // the bounds of the canvas in model space
    }
}

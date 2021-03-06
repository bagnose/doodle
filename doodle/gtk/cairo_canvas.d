module doodle.gtk.cairo_canvas;

public {
    import doodle.dia.icanvas;
    import doodle.gtk.events;
}

private {
    import doodle.core.logging;
    import doodle.tk.screen_model;
    import doodle.dia.layer_stack;
    import doodle.gtk.cairo_renderer;

    import cairo.Surface;
    import cairo.Context;

    import gtk.Widget;
    import gtk.Toolbar;
    import gtk.Table;
    import gtk.Label;
    alias gtk.Label.Label HRuler;
    alias gtk.Label.Label VRuler;
    import gtk.Range;
    import gtk.HScrollbar;
    import gtk.VScrollbar;
    import gtk.DrawingArea;
    import gtk.Adjustment;

    import gtkc.gtk;
    import gtkc.gtktypes;
    //import gtkc.gdktypes;

    import std.math;
    import std.stdio;
    import core.thread;
}

// Bring doodle.tk.geometry.Rectangle into local namespace so we
// get it instead of gdk.Rectangle.Rectangle
alias doodle.tk.geometry.Rectangle Rectangle;

final class CairoCanvas : Table, IViewport {
    static this() {
        _cursors = [
            Cursor.DEFAULT   : CursorType.ARROW,
            Cursor.HAND      : CursorType.HAND1,
            Cursor.CROSSHAIR : CursorType.CROSSHAIR,
            Cursor.PENCIL    : CursorType.PENCIL
            ];
    }

    this(Layer[] layers, IEventHandler eventHandler, IGrid grid, in double pixelsPerMillimetre) {
        super(3, 3, 0);

        _eventHandler = eventHandler;
        _grid = grid;
        _pixelsPerMillimetre = pixelsPerMillimetre;

        _layerStack = new LayerStack(layers);

        // Create our child widgets and register callbacks

        _hRuler = new HRuler("horizontal");
        attach(_hRuler,
               1, 2,
               0, 1,
               AttachOptions.FILL | AttachOptions.EXPAND, AttachOptions.SHRINK,
               0, 0);
        //_hRuler.setMetric(MetricType.PIXELS);

        _vRuler = new VRuler("vertical");
        attach(_vRuler,
               0, 1,
               1, 2,
               AttachOptions.SHRINK, AttachOptions.FILL | AttachOptions.EXPAND,
               0, 0);
        //_vRuler.setMetric(MetricType.PIXELS);

        _drawingArea = new DrawingArea;
        _drawingArea.addOnRealize(&onRealize);
        _drawingArea.addOnConfigure(&onConfigure);
        _drawingArea.addOnDraw(&onDraw);
        _drawingArea.addOnButtonPress(&onButtonPress);
        _drawingArea.addOnButtonRelease(&onButtonRelease);
        _drawingArea.addOnKeyPress(&onKeyPressEvent);
        _drawingArea.addOnKeyRelease(&onKeyReleaseEvent);
        _drawingArea.addOnMotionNotify(&onMotionNotify);
        _drawingArea.addOnScroll(&onScroll);
        _drawingArea.addOnEnterNotify(&onEnterNotify);
        _drawingArea.addOnLeaveNotify(&onLeaveNotify);

        _drawingArea.addOnFocusIn(&onFocusIn);
        _drawingArea.addOnFocusOut(&onFocusOut);
        _drawingArea.addOnMoveFocus(&onMoveFocus);
        _drawingArea.addOnGrabBroken(&onGrabBroken);
        _drawingArea.addOnGrabFocus(&onGrabFocus);
        _drawingArea.addOnGrabNotify(&onGrabNotify);
        // addOnPopupMenu
        // addOnQueryTooltip
        // addOnSelection*
        _drawingArea.setEvents(EventMask.POINTER_MOTION_MASK |
                               EventMask.POINTER_MOTION_HINT_MASK |
                               EventMask.BUTTON_MOTION_MASK |
                               EventMask.BUTTON_PRESS_MASK |
                               EventMask.BUTTON_RELEASE_MASK |
                               EventMask.KEY_PRESS_MASK |
                               EventMask.KEY_RELEASE_MASK |
                               EventMask.ENTER_NOTIFY_MASK |
                               EventMask.LEAVE_NOTIFY_MASK |
                               EventMask.FOCUS_CHANGE_MASK |
                               EventMask.SCROLL_MASK);

        _drawingArea.setCanFocus(true);

        attach(_drawingArea,
               1, 2,
               1, 2, 
               AttachOptions.FILL | AttachOptions.EXPAND, AttachOptions.FILL | AttachOptions.EXPAND,
               0, 0);

        // value, lower, upper, step-inc, page-inc, page-size
        // Give the adjustments dummy values until we receive a configure
        _hAdjustment = new Adjustment(0.0, 0.0, 1.0, 0.2, 0.5, 0.5);
        _hAdjustment.addOnValueChanged(&onAdjustmentValueChanged);
        _hScrollbar = new HScrollbar(_hAdjustment);
        _hScrollbar.setInverted(false);
        attach(_hScrollbar,
               1, 2,
               2, 3,
               AttachOptions.FILL | AttachOptions.EXPAND,
               AttachOptions.SHRINK,
               0, 0);

        _vAdjustment = new Adjustment(0.0, 0.0, 1.0, 0.2, 0.5, 0.5);
        _vAdjustment.addOnValueChanged(&onAdjustmentValueChanged);
        _vScrollbar = new VScrollbar(_vAdjustment);
        _vScrollbar.setInverted(true);
        attach(_vScrollbar,
               2, 3,
               1, 2,
               AttachOptions.SHRINK,
               AttachOptions.FILL | AttachOptions.EXPAND,
               0, 0);
    }

    protected {         // XXX the compiler complains about unimplemented methods if this is private

        // IViewport overrides:

        void zoomRelative(in double factor, in Point screenDatum) {
            _screenModel.zoomRelative(factor, screenDatum);
            consolidateBounds();
            updateAdjustments();
            updateRulers();
            _grid.zoomChanged(_screenModel.zoom);
            queueDraw();
        }

        void panRelative(in Vector screenDisplacement) {
            _screenModel.panRelativeScreen(screenDisplacement);
            consolidateBounds();
            updateAdjustments();
            updateRulers();
            queueDraw();
        }

        void setCursor(in Cursor cursor) {
            _drawingArea.setCursor(new gdk.Cursor.Cursor(_cursors[cursor]));
        }

        void damageModel(in Rectangle area) {
            _damageScreen = _damageScreen | _screenModel.modelToScreen(area);
        }

        void damageScreen(in Rectangle area) {
            _damageScreen = _damageScreen | area;
        }
    }

    private {

        void consolidateBounds() {
            Rectangle layerBounds = _layerStack.bounds;
            Rectangle paddedLayerBounds = growCentre(layerBounds, 2 * layerBounds.size);
            _screenModel.consolidateCanvasBounds(paddedLayerBounds);

            updateAdjustments();
            updateRulers();
        }

        bool onConfigure(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);

            //_surface = ImageSurface.create(CairoFormat.ARGB32, event.configure().width, event.configure().height);

            auto viewBoundsScreen = Rectangle(Point(0.0, 0.0), Vector(cast(double)event.configure().width, cast(double)event.configure().height));

            if (_screenModel is null) {
                Rectangle layerBounds = _layerStack.bounds;
                Rectangle paddedLayerBounds = growCentre(layerBounds, 2 * layerBounds.size);
                _screenModel = new ScreenModel(0.25 * _pixelsPerMillimetre, paddedLayerBounds, viewBoundsScreen);
                _grid.zoomChanged(_screenModel.zoom);

                updateAdjustments();
                updateRulers();
            }
            else {
                _screenModel.setViewBoundsScreen(viewBoundsScreen);
                consolidateBounds();
            }

            return true;
        }

        bool onDraw(Context context, Widget widget) {
            assert(widget is _drawingArea);

            double x0, y0, x1, y1;
            context.clipExtents(x0, y0, x1, y1);
            Rectangle screenDamage =
                Rectangle(_screenModel.viewBoundsScreen.position +
                          Vector(x0, _screenModel.viewBoundsScreen.h - y1),
                          Vector(x1 - x0, y1 - y0));
            assert(screenDamage.valid);

            //writefln("External screen damage: %s", screenDamage);

            Rectangle modelDamage = _screenModel.screenToModel(screenDamage);

            scope Context modelCr  = Context.create(context.getTarget());
            scope Context screenCr = Context.create(context.getTarget());

            modelCr.save(); screenCr.save(); {
                {
                    // Setup model context and clip
                    modelCr.translate(0.0, _screenModel.viewBoundsScreen.h);
                    modelCr.scale(_screenModel.zoom, -_screenModel.zoom);

                    immutable Point viewLeftBottom = _screenModel.screenToModel(Point(0.0, 0.0));
                    modelCr.translate(-viewLeftBottom.x, -viewLeftBottom.y);

                    modelCr.rectangle(modelDamage.x0, modelDamage.y0, modelDamage.w, modelDamage.h);
                    modelCr.clip();
                }

                {
                    // Setup screen context and clip
                    screenCr.translate(0.0, _screenModel.viewBoundsScreen.h);
                    screenCr.scale(1.0, -1.0);

                    screenCr.rectangle(screenDamage.x0, screenDamage.y0, screenDamage.w, screenDamage.h);
                    screenCr.clip();
                }

                screenCr.save(); {
                    // Fill the background with light grey
                    screenCr.setSourceRgba(0.9, 0.9, 0.9, 1.0);
                    screenCr.rectangle(screenDamage.x0, screenDamage.y0, screenDamage.w, screenDamage.h);
                    screenCr.fill();
                } screenCr.restore();

                _layerStack.draw(screenDamage, new CairoRenderer(screenCr),
                                 modelDamage,  new CairoRenderer(modelCr),
                                 _screenModel);
            } screenCr.restore(); screenCr.restore();

            return true;
        }

        bool onButtonPress(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleButtonPress(this, makeButtonEvent(event.button(), _screenModel));
            reportDamage();
            return true;
        }

        bool onButtonRelease(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleButtonRelease(this, makeButtonEvent(event.button(), _screenModel));
            reportDamage();
            return true;
        }

        bool onKeyPressEvent(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleKeyPress(this, makeKeyEvent(event.key(), _screenModel));
            reportDamage();
            return true;
        }

        bool onKeyReleaseEvent(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleKeyRelease(this, makeKeyEvent(event.key(), _screenModel));
            reportDamage();
            return true;
        }

        bool onMotionNotify(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);

            if (event.motion().isHint) {
                int x, y;
                GdkModifierType mask;
                _drawingArea.getWindow().getPointer(x, y, mask);
                _eventHandler.handleMotion(this, makeMotionEventHint(x, y, mask, _screenModel));
            }
            else {
                _eventHandler.handleMotion(this, makeMotionEvent(event.motion(), _screenModel));
            }

            reportDamage();

            // Pass the events on to the rulers so that they update
            _hRuler.event(event);
            _vRuler.event(event);

            /+
            // Simulate delay in case we were slow to handle the event.
            // This is really only relevant if we were to do the drawing from inside
            // the handler. ???
            Thread.sleep(dur!("msecs")(250));
            +/

            return true;
        }

        bool onScroll(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleScroll(this, makeScrollEvent(event.scroll(), _screenModel));
            reportDamage();
            return true;
        }

        bool onEnterNotify(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleEnter(this, makeCrossingEvent(event.crossing(), _screenModel));
            reportDamage();
            return true;
        }

        bool onLeaveNotify(gdk.Event.Event event, Widget widget) {
            assert(widget is _drawingArea);
            _eventHandler.handleLeave(this, makeCrossingEvent(event.crossing(), _screenModel));
            reportDamage();
            return true;
        }

        bool onFocusIn(gdk.Event.Event event, Widget widget) {
            trace("onFocusIn");
            return true;
        }

        bool onFocusOut(gdk.Event.Event event, Widget widget) {
            trace("onFocusOut");
            return true;
        }

        void onMoveFocus(GtkDirectionType direction, Widget widget) {
            trace("onMoveFocus");
        }

        bool onGrabBroken(gdk.Event.Event event, Widget widget) {
            trace("onGrabBroken");
            return true;
        }

        void onGrabFocus(Widget widget) {
            //trace("onGrabFocus");
        }

        void onGrabNotify(gboolean what, Widget widget) {
            trace("onGrabNotify: %s", what);
        }

        void onAdjustmentValueChanged(Adjustment adjustment) {
            GtkAdjustment * hGtkAdjustment = _hAdjustment.getAdjustmentStruct();
            GtkAdjustment * vGtkAdjustment = _vAdjustment.getAdjustmentStruct();

            Point oldViewLeftBottom = _screenModel.screenToModel(Point(0.0, 0.0));
            Point newViewLeftBottom = Point(gtk_adjustment_get_value(hGtkAdjustment),
                                            gtk_adjustment_get_value(vGtkAdjustment));

            _screenModel.panRelativeModel(newViewLeftBottom - oldViewLeftBottom);

            updateRulers();
            queueDraw();
        }

        void updateRulers() {
            immutable Point viewLeftBottom = _screenModel.screenToModel(_screenModel.viewBoundsScreen.corner0);
            immutable Point viewRightTop = _screenModel.screenToModel(_screenModel.viewBoundsScreen.corner1);

            // Define these just to obtain the position
            // below so we can preserve it
            double lower, upper, position, maxSize;

            /+
            _hRuler.getRange(lower, upper, position, maxSize);
            _hRuler.setRange(viewLeftBottom.x,
                             viewRightTop.x,
                             position,
                             _screenModel.zoom * 50.0);

            _vRuler.getRange(lower, upper, position, maxSize);
            _vRuler.setRange(viewRightTop.y,
                             viewLeftBottom.y,
                             position,
                             _screenModel.zoom * 50.0);
            +/
        }

        void updateAdjustments() {
            immutable Point viewLeftBottom = _screenModel.screenToModel(Point(0.0, 0.0));
            immutable Point viewRightTop = _screenModel.screenToModel(_screenModel.viewBoundsScreen.corner1);

            // Adjust the canvas size if necessary
            _screenModel.canvasAccommodate(Rectangle(viewLeftBottom, viewRightTop));

            Rectangle viewBoundsModel = _screenModel.viewBoundsModel;

            // Update the adjustments
            _hAdjustment.configure(viewLeftBottom.x,
                                   _screenModel.canvasBoundsModel.x0,
                                   _screenModel.canvasBoundsModel.x1,
                                   _screenModel.canvasBoundsModel.w / 16.0,
                                   _screenModel.canvasBoundsModel.w / 4.0,
                                   _screenModel.viewBoundsModel.w);
            _vAdjustment.configure(viewLeftBottom.y,
                                   _screenModel.canvasBoundsModel.y0,
                                   _screenModel.canvasBoundsModel.y1,
                                   _screenModel.canvasBoundsModel.h / 16.0,
                                   _screenModel.canvasBoundsModel.h / 4.0,
                                   _screenModel.viewBoundsModel.h);
        }

        void reportDamage() {
            if (_damageScreen.valid) {
                int x, y, w, h;
                _damageScreen.getQuantised(x, y, w, h);
                _drawingArea.queueDrawArea(x, cast(int)_screenModel.viewBoundsScreen.h - (y + h), w, h);
                _damageScreen = Rectangle();

                // Force the damage to be fixed now.
                // If we don't do this then additional input events
                // can keep piling up.
                _drawingArea.getWindow().processAllUpdates();
            }
            assert(!_damageScreen.valid);
        }

        void onRealize(Widget widget) {
            assert(widget is _drawingArea);
            _drawingArea.grabFocus();
        }

        IEventHandler _eventHandler;
        IGrid         _grid;
        double        _pixelsPerMillimetre;
        LayerStack    _layerStack;

        // Child widgets:
        HRuler        _hRuler;
        VRuler        _vRuler;
        DrawingArea   _drawingArea;
        Adjustment    _hAdjustment;
        HScrollbar    _hScrollbar;
        Adjustment    _vAdjustment;
        VScrollbar    _vScrollbar;

        Rectangle     _damageScreen;        // accumulated from damageModel and damageScreen calls
        ScreenModel   _screenModel;

        static immutable CursorType[Cursor] _cursors;
    }
}

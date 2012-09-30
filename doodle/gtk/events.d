module doodle.gtk.events;

public {
    import doodle.tk.events;
}

private {
    import core.stdc.string : strlen;
    static import gdk.Event;
}

private {

    ButtonAction gtk2tkButtonAction(gdk.Event.EventType event_type) {
        switch (event_type) {
        case gdk.Event.EventType.BUTTON_PRESS:        return ButtonAction.SINGLE_PRESS;
        case gdk.Event.EventType.DOUBLE_BUTTON_PRESS: return ButtonAction.DOUBLE_PRESS;
        case gdk.Event.EventType.TRIPLE_BUTTON_PRESS: return ButtonAction.TRIPLE_PRESS;
        case gdk.Event.EventType.BUTTON_RELEASE:      return ButtonAction.RELEASE;
        default:
                                                      assert(false);
        }
    }

    ButtonName gtk2tkButtonName(gdk.Event.guint button) {
        switch (button) {
        case 1: return ButtonName.LEFT;
        case 2: return ButtonName.MIDDLE;
        case 3: return ButtonName.RIGHT;
        case 4: return ButtonName.FOUR;
        case 5: return ButtonName.FIVE;
        default:
                assert(false);
        }
    }

    Mask gtk2tkMask(gdk.Event.guint state) {
        Modifier[] modifiers;

        if (state & gdk.Event.GdkModifierType.SHIFT_MASK)   modifiers ~= Modifier.SHIFT;
        if (state & gdk.Event.GdkModifierType.CONTROL_MASK) modifiers ~= Modifier.CONTROL;
        if (state & gdk.Event.GdkModifierType.MOD1_MASK)    modifiers ~= Modifier.ALT;
        if (state & gdk.Event.GdkModifierType.MOD2_MASK)    modifiers ~= Modifier.META;
        // Note, MOD 3-5 are currently omitted
        if (state & gdk.Event.GdkModifierType.BUTTON1_MASK) modifiers ~= Modifier.LEFT_BUTTON;
        if (state & gdk.Event.GdkModifierType.BUTTON2_MASK) modifiers ~= Modifier.MIDDLE_BUTTON;
        if (state & gdk.Event.GdkModifierType.BUTTON3_MASK) modifiers ~= Modifier.RIGHT_BUTTON;
        if (state & gdk.Event.GdkModifierType.BUTTON4_MASK) modifiers ~= Modifier.UNUSED_BUTTON_1;
        if (state & gdk.Event.GdkModifierType.BUTTON5_MASK) modifiers ~= Modifier.UNUSED_BUTTON_2;

        Mask m = Mask(modifiers);

        return Mask(modifiers);
    }

    ScrollDirection gtk2tkDirection(gdk.Event.ScrollDirection direction) {
        switch (direction) {
        case gdk.Event.ScrollDirection.UP:    return ScrollDirection.UP;
        case gdk.Event.ScrollDirection.DOWN:  return ScrollDirection.DOWN;
        case gdk.Event.ScrollDirection.LEFT:  return ScrollDirection.LEFT;
        case gdk.Event.ScrollDirection.RIGHT: return ScrollDirection.RIGHT;
        default:
                                              assert(false);
        }
    }

    CrossingMode gtk2tkCrossingMode(gdk.Event.CrossingMode crossingMode) {
        switch (crossingMode) {
        case crossingMode.NORMAL:        return CrossingMode.NORMAL;
        case crossingMode.GRAB:          return CrossingMode.GRAB;
        case crossingMode.UNGRAB:        return CrossingMode.UNGRAB;
        case crossingMode.GTK_GRAB:      return CrossingMode.GRAB2;
        case crossingMode.GTK_UNGRAB:    return CrossingMode.UNGRAB2;
        case crossingMode.STATE_CHANGED: return CrossingMode.STATE_CHANGED;
        default:
                                         assert(false);
        }
    }

}

// Functions for creating the events

/*
   public struct GdkEventButton {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   uint time;
   double x;
   double y;
   double *axes;
   uint state;
   uint button;
   GdkDevice *device;
   double xRoot, yRoot;
   }
*/

ButtonEvent makeButtonEvent(const gdk.Event.GdkEventButton * event, in ScreenModel screenModel) {
    Point screenPoint = Point(event.x + 0.5, screenModel.viewBoundsScreen.h - (event.y + 0.5));
    Point modelPoint = screenModel.screenToModel(screenPoint);
    return new ButtonEvent(gtk2tkButtonAction(event.type),
                           gtk2tkButtonName(event.button),
                           screenPoint, modelPoint, gtk2tkMask(event.state));
}

/*
   public struct GdkEventMotion {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   uint time;
   double x;
   double y;
   double *axes;
   uint state;
   short isHint;
   GdkDevice *device;
   double xRoot, yRoot;
   }
 */

MotionEvent makeMotionEvent(const gdk.Event.GdkEventMotion * event, in ScreenModel screenModel) {
    assert(!event.isHint);
    Point screenPoint = Point(event.x + 0.5, screenModel.viewBoundsScreen.h - (event.y + 0.5));
    Point modelPoint = screenModel.screenToModel(screenPoint);
    return new MotionEvent(screenPoint, modelPoint, gtk2tkMask(event.state));
}

MotionEvent makeMotionEventHint(int x, int y, gdk.Event.GdkModifierType mask, in ScreenModel screenModel) {
    Point screenPoint = Point(cast(double)x + 0.5, screenModel.viewBoundsScreen.h - (cast(double)y + 0.5));
    Point modelPoint = screenModel.screenToModel(screenPoint);
    return new MotionEvent(screenPoint, modelPoint, gtk2tkMask(cast(gdk.Event.guint)mask));
}

/*
   public struct GdkEventKey {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   uint time;
   uint state;
   uint keyval;
   int length;
   char *string;
   ushort hardwareKeycode;
   ubyte group;
   uint bitfield0;
   uint isModifier : 1;
   }
 */

KeyEvent makeKeyEvent(const gdk.Event.GdkEventKey * event, in ScreenModel screenModel) {
    return new KeyEvent(event.string[0..strlen(event.string)].idup,
                        event.keyval,
                        gtk2tkMask(event.state));
}

/*
   public struct GdkEventScroll {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   uint time;
   double x;
   double y;
   uint state;
   GdkScrollDirection direction;
   GdkDevice *device;
   double xRoot, yRoot;
   }
 */

ScrollEvent makeScrollEvent(const gdk.Event.GdkEventScroll * event, in ScreenModel screenModel) {
    Point screenPoint = Point(event.x + 0.5, screenModel.viewBoundsScreen.h - (event.y + 0.5));
    Point modelPoint = screenModel.screenToModel(screenPoint);
    return new ScrollEvent(gtk2tkDirection(event.direction),
                           screenPoint,
                           modelPoint,
                           gtk2tkMask(event.state));
}

/*
   public enum GdkCrossingMode {       
   NORMAL,
   GRAB,
   UNGRAB,
   GTK_GRAB,
   GTK_UNGRAB,
   STATE_CHANGED
   }

   public struct GdkEventCrossing {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   GdkWindow *subwindow;
   uint time;
   double x;
   double y;
   double xRoot;
   double yRoot;
   GdkCrossingMode mode;
   GdkNotifyType detail;
   int focus;
   uint state;
   }
 */

CrossingEvent makeCrossingEvent(const gdk.Event.GdkEventCrossing * event, in ScreenModel screenModel) {
    Point screenPoint = Point(event.x + 0.5, screenModel.viewBoundsScreen.h - (event.y + 0.5));
    Point modelPoint = screenModel.screenToModel(screenPoint);
    return new CrossingEvent(gtk2tkCrossingMode(event.mode),
                             screenPoint,
                             modelPoint,
                             gtk2tkMask(event.state));
}


/*
   public struct GdkEventFocus {
   GdkEventType type;
   GdkWindow *window;
   byte sendEvent;
   short inn;
   }
 */
// In case we implement focus event...

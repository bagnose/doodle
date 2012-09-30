module doodle.tk.events;

public {
    import doodle.tk.geometry;
    import doodle.tk.screen_model;
}

private {
    import std.conv;
}

enum ButtonAction {
    SINGLE_PRESS,
    DOUBLE_PRESS,
    TRIPLE_PRESS,
    RELEASE
}

enum ButtonName {
    LEFT,
    MIDDLE,
    RIGHT,
    FOUR,
    FIVE
}

enum ScrollDirection {
    UP,
    DOWN,
    LEFT,
    RIGHT
}

enum Modifier {
    SHIFT,
    CAPS_LOCK,
    CONTROL,
    ALT,
    NUM_LOCK,
    META,
    SCROLL_LOCK,
    LEFT_BUTTON,
    MIDDLE_BUTTON,
    RIGHT_BUTTON,
    UNUSED_BUTTON_1,
    UNUSED_BUTTON_2
}

enum CrossingMode {           // FIXME what to do about GRAB2/UNGRAB2
    NORMAL,
    GRAB,
    UNGRAB,
    GRAB2,
    UNGRAB2,
    STATE_CHANGED
}

struct Mask {
    this(in Modifier[] modifiers) {
        foreach (m; modifiers) {
            _bits |= 1 << m;
        }
    }

    string toString() {
        if (_bits == 0) {
            return "<NO_MASK>";
        }
        else {
            string s = "";

            for (int i = 0; i < _bits.sizeof * 8; ++i) {
                if (_bits & (1 << i)) {
                    if (s.length != 0) s ~= "|";
                    s ~= to!string(cast(Modifier)i);
                }
            }

            return s;
        }
    }

    bool isSet(in Modifier m) const { return cast(bool)(_bits & (1 << m)); }
    bool isUnset(in Modifier m) const { return !isSet(m); }

    private immutable ushort _bits;
}

// FIXME
// Do we need FocusEvent. Note, it has no mask.
// Hence would need to refactor hierarchy slightly, eg InputEvent

abstract class Event {
    this(in Mask mask) {
        _mask = mask;
    }

    @property Mask mask() const { return _mask; }

    private {
        Mask _mask;
    }
}

final class KeyEvent : Event {
    this(in string str, in uint value, in Mask mask) {
        super(mask);
        _str = str;
        _value = value;
    }

    @property string str() const { return _str; }
    @property uint value() const { return _value; }

    override string toString() const {
        return std.string.format("Key event: %s, %d, %s", _str, _value, _mask);
    }

    private {
        string _str;
        uint _value;
    }
}

abstract class PointerEvent : Event {
    this(in Point screenPoint, in Point modelPoint, in Mask mask) {
        super(mask);
        _screenPoint = screenPoint;
        _modelPoint = modelPoint;
    }

    @property Point screenPoint() const { return _screenPoint; }
    @property Point modelPoint() const { return _modelPoint; }

    private {
        Point _screenPoint;
        Point _modelPoint;
    }
}

final class CrossingEvent : PointerEvent {
    this(in CrossingMode crossingMode,
         in Point screenPoint,
         in Point modelPoint,
         in Mask mask) {
        super(screenPoint, modelPoint, mask);
        _crossingMode = crossingMode;
    }

    @property CrossingMode crossingMode() const { return _crossingMode; }

    override string toString() const {
        return std.string.format("Crossing event: %s, %s, %s, %s", to!string(_crossingMode), screenPoint, modelPoint, mask);
    }

    private {
        CrossingMode _crossingMode;
    }
}

final class ButtonEvent : PointerEvent {
    this(in ButtonAction buttonAction,
         in ButtonName buttonName,
         in Point screenPoint,
         in Point modelPoint,
         in Mask mask) {   
        super(screenPoint, modelPoint, mask);
        _buttonAction = buttonAction;
        _buttonName = buttonName;
    }

    override string toString() const {
        return std.string.format("Button event: %s, %s, %s, %s, %s",
                                 to!string(_buttonAction), to!string(_buttonName),
                                 _screenPoint, _modelPoint, _mask);
    }

    @property ButtonAction buttonAction() const { return _buttonAction; }
    @property ButtonName buttonName() const { return _buttonName; }

    private {
        ButtonAction _buttonAction;
        ButtonName _buttonName;
    }
}

final class MotionEvent : PointerEvent {
    this(in Point screenPoint,
         in Point modelPoint,
         in Mask mask) {
        super(screenPoint, modelPoint, mask);
    }

    override string toString() const {
        return std.string.format("Motion event: %s, %s, %s",
                                 _screenPoint, _modelPoint, _mask);
    }
}

final class ScrollEvent : PointerEvent {
    this(in ScrollDirection scrollDirection,
         in Point screenPoint,
         in Point modelPoint,
         in Mask mask) {
        super(screenPoint, modelPoint, mask);
        _scrollDirection = scrollDirection;
    }

    override string toString() const {
        return std.string.format("Scroll event: %s, %s, %s, %s",
                                 to!string(_scrollDirection), _screenPoint, _modelPoint, _mask);
    }

    @property ScrollDirection scrollDirection() const { return _scrollDirection; }

    private {
        ScrollDirection _scrollDirection;
    }
}

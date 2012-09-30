module doodle.dia.tool_layer;

public {
    import doodle.dia.tool;
}

private {
    import doodle.core.logging;
}

// This interface is used by the palette
interface IToolStack {      // Rename this because the stack aspect is not significant.
    void use(Tool tool);
}

interface IToolStackObserver {
    void toolChanged(Tool tool);
}

final class ToolLayer : Layer, IEventHandler, IToolStack {
    this(Tool[] staticTools, IToolStackObserver observer, in string name = "Tool") {
        super(name);
        _staticTools = staticTools.dup;
        _observer = observer;
    }

    // IToolStack overrides:

    void use(Tool tool) {
        assert(_grabbedTool is null);
        message("using new tool: %s", tool.name);
        _staticTools ~= tool;
        _observer.toolChanged(tool);
    }

    // Layer overrides:

    override Rectangle bounds() const {
        return Rectangle();
    }

    override void draw(in Rectangle screenDamage, scope Renderer screenRenderer,
                       in Rectangle modelDamage, scope Renderer modelRenderer,
                       in ScreenModel screenModel) const {
        if (_grabbedTool) {
            _grabbedTool.draw(screenDamage, screenRenderer);
        }
    }

    // EventHandler overrides:

    bool handleButtonPress(scope IViewport viewport, in ButtonEvent event) {
        // writefln("%s", event);

        if (_grabbedTool is null) {
            foreach_reverse(ref tool; _staticTools) {
                if (tool.handleButtonPress(viewport, event)) {
                    _grabbedTool = tool;
                    _grabbedButton = event.buttonName;
                    break;
                }
            }
        }
        else {
            _grabbedTool.handleButtonPress(viewport, event);
        }

        return true;
    }

    bool handleButtonRelease(scope IViewport viewport, in ButtonEvent event) {
        // writefln("%s", event);

        if (_grabbedTool !is null) {
            _grabbedTool.handleButtonRelease(viewport, event);

            if (_grabbedButton == event.buttonName) {
                _grabbedTool = null;
            }
        }

        return true;
    }

    bool handleMotion(scope IViewport viewport, in MotionEvent event) {
        //writefln("%s", event);

        if (_grabbedTool is null) {
            foreach_reverse(ref tool; _staticTools) {
                if (tool.handleMotion(viewport, event)) {
                    break;
                }
            }
        }
        else {
            _grabbedTool.handleMotion(viewport, event);
        }

        return true;
    }

    bool handleScroll(scope IViewport viewport, in ScrollEvent event) {
        // writefln("%s", event);

        if (_grabbedTool is null) {
            foreach_reverse(ref tool; _staticTools) {
                if (tool.handleScroll(viewport, event)) {
                    break;
                }
            }
        }
        else {
            _grabbedTool.handleScroll(viewport, event);
        }

        return true;
    }

    bool handleEnter(scope IViewport viewport, in CrossingEvent event) {
        trace("Enter %s", event);

        if (_grabbedTool is null) {
            foreach_reverse(ref tool; _staticTools) {
                if (tool.handleEnter(viewport, event)) {
                    break;
                }
            }
        }
        else {
            _grabbedTool.handleEnter(viewport, event);
        }

        return true;
    }

    bool handleLeave(scope IViewport viewport, in CrossingEvent event) {
        trace("Leave %s", event);

        if (_grabbedTool is null) {
            foreach_reverse(ref tool; _staticTools) {
                if (tool.handleLeave(viewport, event)) {
                    break;
                }
            }
        }
        else {
            _grabbedTool.handleLeave(viewport, event);
        }

        return true;
    }

    bool handleKeyPress(scope IViewport viewport, in KeyEvent event) {
        // writefln("%s", event);

        // FIXME not sure how these should work
        foreach_reverse(ref tool; _staticTools) {
            if (tool.handleKeyPress(viewport, event)) {
                break;
            }
        }

        return true;
    }

    bool handleKeyRelease(scope IViewport viewport, in KeyEvent event) {
        // writefln("%s", event);

        // FIXME not sure how these should work
        foreach_reverse(ref tool; _staticTools) {
            if (tool.handleKeyRelease(viewport, event)) {
                break;
            }
        }

        return true;
    }

    private {
        Tool[] _staticTools;
        IToolStackObserver _observer;

        Tool _grabbedTool;
        ButtonName _grabbedButton;
    }
}

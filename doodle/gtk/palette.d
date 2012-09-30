module doodle.gtk.palette;

public {
    import doodle.tk.palette;
    import gtk.Toolbar;
}

private {
    import doodle.core.logging;
    import gtk.ToolButton;
    import gtk.RadioToolButton;
    import gtk.Image;
    import gtk.Label;
    import glib.ListSG;
    import std.stdio;
}

class Palette(T) : Toolbar, IPalette!T {
    this() {
        // INVALID, MENU, SMALL_TOOLBAR, LARGE_TOOLBAR,
        // BUTTON, DND, DIALOG
        setIconSize(GtkIconSize.LARGE_TOOLBAR);
        // ICONS, TEXT, BOTH, BOTH_HORIZ
        setStyle(GtkToolbarStyle.ICONS);
        // HORIZONTAL, VERTICAL
        setOrientation(GtkOrientation.HORIZONTAL);
    }

    override void configure(Item[] items, Callback callback) {
        _callback = callback;

        RadioToolButton group;

        foreach(index, item; items) {
            RadioToolButton button;

            if (index == 0) {
                ListSG list;
                button = new RadioToolButton(list);
                group = button;
            }
            else {
                button = new RadioToolButton(group);
            }

            auto image = new Image(_iconBase ~ "/" ~ item.iconPath);
            auto label = new Label(item.labelText);
            button.setIconWidget(image);
            button.setLabelWidget(label);
            button.setTooltipText(item.tooltipText);

            _buttons[item.t] = button;
            button.setDataFull(_indexStr, cast(gpointer)item.t, null);
            button.addOnClicked(&onClicked);

            insert(button);
        }
    }

    void activate(T t) {
        RadioToolButton button = _buttons[t];
        if (!button.getActive()) {
            button.setActive(true);
        }
    }

    private {
        immutable _iconBase = "/home/daveb/source/d/doodle/doodle/gtk/data";
        immutable _indexStr = "index";

        Callback _callback;
        RadioToolButton[T] _buttons;

        void onClicked(ToolButton toolButton) {
            RadioToolButton button = cast(RadioToolButton)toolButton;
            if (button.getActive()) {
                T t = cast(T)button.getData(_indexStr);
                _callback(t);
            }
        }
    }
}

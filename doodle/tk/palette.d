module doodle.tk.palette;

// XXX Not sure whether to use delegates or observer pattern...

interface IPalette(T) {
    struct Item {
        string iconPath;
        string labelText;
        string tooltipText;
        T t;
    };

    alias void delegate(T) Callback;

    void configure(Item[] items, Callback callback);
    void activate(T t);
}

module main.prog.doodler;

// XXX bob problem, needs it to be like this...
import doodle.core.backtrace;
import doodle.core.logging;
import doodle.core.backtrace;

import doodle.dia.standard_tools;
import doodle.dia.page_layer;
import doodle.dia.grid_layer;
import doodle.dia.tool_layer;

import doodle.fig.diagram_layer;
import doodle.fig.select_tool;

import doodle.fig.tools;

import doodle.gtk.palette;

import doodle.gtk.cairo_canvas;

private {
    /*
    import doodle.core.backtrace;
    import doodle.core.logging;
    import doodle.core.backtrace;

    import doodle.dia.standard_tools;
    import doodle.dia.page_layer;
    import doodle.dia.grid_layer;
    import doodle.dia.tool_layer;

    import doodle.fig.diagram_layer;
    import doodle.fig.select_tool;

    import doodle.fig.tools;

    import doodle.gtk.palette;

    import doodle.gtk.cairo_canvas;
    */

    import gtk.Main;
    import gtk.MainWindow;
    import gtk.VBox;

    import std.stdio;
}

final class TopLevel : /*private*/ IToolStackObserver {
    this(string[] args) {
        Main.init(args);
        auto window = new MainWindow("Doodle");
        auto vbox = new VBox(false, 0);

        auto palette = new Palette!Tool;
        _palette = palette;

        vbox.packStart(palette, false, false, 0);

        Tool[] tools;
        tools ~= new PanTool;
        tools ~= new ZoomTool;
        tools ~= new SelectTool;
        auto toolLayer = new ToolLayer(tools, this);
        _toolStack = toolLayer;

        auto gridLayer = new GridLayer;

        auto diagramLayer = new DiagramLayer;
        _diagram = diagramLayer;

        Layer[] layers;
        layers ~= new PageLayer;
        layers ~= gridLayer;
        layers ~= diagramLayer;
        layers ~= toolLayer;

        // assume the screen has PPI of 120.0
        immutable millimetersPerInch = 25.4;
        immutable pixelsPerMillimetre = 120.0 / millimetersPerInch;
        auto canvas = new CairoCanvas(layers, toolLayer, gridLayer, pixelsPerMillimetre);

        vbox.packStart(canvas, true, true, 0);

        Palette!Tool.Item[] items = [
        { "select.svg",    "Select",    "Select and modify elements", new SelectTool },
        { "rectangle.svg", "Rectangle", "Create rectangle", new CreateRectangleTool(_diagram) },
        { "ellipse.svg",   "Ellipse",   "Create ellipse", new CreateRectangleTool(_diagram) },
        { "polyline.svg",  "Polyline",  "Create polyline", new CreateRectangleTool(_diagram) }
        ];

        palette.configure(items, &_toolStack.use);
        window.add(vbox);
        window.setDefaultSize(640, 580);
        window.showAll();
        Main.run();
    }

    void toolChanged(Tool tool) {
        message("Tool changed %s", tool.name);
        _palette.activate(tool);
    }

    private {
        IToolStack _toolStack;
        IPalette!Tool _palette;
        IDiagram _diagram;
    }
}

void main(string[] args) {
    new TopLevel(args);
}

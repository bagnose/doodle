==================
Doodle Development
==================

*NOTE* this document is currently just a dumping ground for stuff.
Don't take it seriously, yet.

Introduction
============

Overview
--------

Doodle is a graphical tool for creating and editing diagrams
that have an underlying semantic model.

Decisions
---------

- D programming language, GtkD toolkit

- Core code doesn't deal with gtk-isms (such as cairo) directly,
  create high-level interfaces (eg Canvas) to support portability.

- Don't tie doodle to a particular modelling language (such as UML).
  Support generic edge/node style diagrams with no outgoing dependencies
  on UMLisms.

Directory Layout
----------------

Crucial Design Aspects
======================

Tool Stack
----------

Interaction, event handling, etc.

Undo Framework
--------------

Geometry
--------

- Vector    offset in x and y
- Point     position in x and y
- Rectangle
- Line
- Segment

Other candidates

- Polygon
- Dimension (used for width and height) Do we need this in addition to Vector?
- Transform (rotate, translate, scale, shear, matrix-transform, etc)

Drawing Abstraction
-------------------

Detailed Component Descriptions
===============================

Layers

- (Background)
- Page
- Grid
- Diagram/Figs (model-oriented)
- Selection
- Guides
- Tools
- (cursor)

Network abstraction (questions asked of the semantic model)

.. uml:: images/network

  interface INetwork {
    +bool canConnect(Object element1, Object element2)
    +bool canNest(Object superNode, Object subNode)
    +bool canReroute(Object edge, Object old_element, Object new_element)
  }

Core classes:

.. uml:: images/core-classes

  Fig          <|-- Branch
  Branch       <|-- GraphElement
  Branch       <|-- Diagram
  GraphElement <|-- Node
  GraphElement <|-- Edge
  Fig          <|-- Leaf

  GraphElement "1"    *--> "1"   ModelBridge
  Branch       "0..1" *--  "*"   Fig
  GraphElement "1"    *--  "*"   Connector
  Edge         "*"    ---  "2"   Connector
  Diagram             *--> "*"   Fig

  abstract class Fig {
    draw(ICanvas modelCanvas, Rectangle modelDamage)
  }

  abstract class Branch {
  }

  abstract class GraphElement {
  }

  abstract class Leaf {
  }

  abstract class ModelBridge {
  }

Leaf classes:

.. uml:: images/leaf-classes

  Leaf         <|-- Text
  Leaf         <|-- Image
  Leaf         <|-- Primitive
  Primitive    <|-- AbstractPoly

  abstract class Primitive {
  }

  abstract class AbstractPoly {
  }

(Distinction between screen-oriented and model-oriented drawing
operations):

.. uml:: images/canvas

  interface ICanvas {
    +pushState()
    +popState()

    +clip()
    +rotate()
    +translate()
    +scale()
    +shear()
    +arbitraryTransform()

    +drawRectangle()
    +drawLine()
    +drawPolyLine()
    +drawString()

    +setFont()
    +setForegroundColor()
    +setBackgroundColor()
    +setLineStyle()
    +setLineJoin()
    +setLineCap()
    +setLineDash()
  }

Appendix
========

xev -id $(xwininfo -name Doodle | grep 'Window id:' | sed -r 's/.*Window id: ([^\s]*) .*"/\1/')

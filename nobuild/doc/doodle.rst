==================
Doodle Development
==================

Introduction
============

Objectives
----------

Directory Layout
----------------

Crucial Design Aspects
======================

Tool Stack
----------

Interaction, event handling, etc.

Undo Framework
--------------

Drawing Abstraction
-------------------

Detailed Component Descriptions
===============================

.. uml:: images/class-hierarchy

    Alice -> Bob: Authentication Request
    Bob --> Alice: Authentication Response

    Alice -> Bob: Another authentication Request
    Alice <-- Bob: another authentication Response


Appendix
========

xev -id $(xwininfo -name Doodle | grep 'Window id:' | sed -r 's/.*Window id: ([^\s]*) .*"/\1/')

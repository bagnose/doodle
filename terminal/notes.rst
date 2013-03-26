Features:

- utf-8

- Scrolling

- Architect for tabs

- Linux centric, backend-agnostic. Port to Xlib, Wayland, etc

- Multiple profiles ?

- Architect for spawn from daemon process (ala urxvt)

- Resizing horizontally changes line-wrapping (urxvt vs xterm)

- Extensions, highlight text regions, clickable for actions

- Support alternative screen (change scrolling, unlike urxvt)

- Mini view, ala sublime edit

- Block select

Decisions:

- Write in C++11. Maybe port to D later.

- Use XCB directly? What about Xft?

- Extension language: lua? python?

Notes:

- How to have a test-suite?

- yaourt -S st / yaourt -S st-git

- yaourt -Ql libxcb libxft

- grab virtual boxes from: http://virtualboxes.org/images/centos/

- Why doesn't st use xcb?

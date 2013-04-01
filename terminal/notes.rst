Features:

- UTF-8

- Scrollback (option for infinite)

- Scroll history de-dupe across terminals.

- Architect for tabs

- Linux centric, backend-agnostic. Port to Xlib, Wayland, etc

- Design for spawn from daemon process (ala urxvt)

- Resizing horizontally changes line-wrapping (urxvt vs xterm)

- Extensions, highlight text regions, clickable for actions

- Support alternative screen (change scrolling, unlike urxvt)

- Mini view, ala sublime edit

- Block select

- Hide cursor when typing.

Decisions:

- Write in C++11. Maybe port to D later.

- Extension language: lua? python?

Notes:

- How to have a test-suite?

- yaourt -S st / yaourt -S st-git

- grab virtual boxes from: http://virtualboxes.org/images/centos/

Links:

- http://rtfm.etla.org/xterm/ctlseq.html

- http://www.vt100.net/docs/

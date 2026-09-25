# ADR-009 — Auto-login root and auto-start CDE on the console

- **Status:** accepted
- **Date:** 2026-09-16

## Context

The 600X is a single-user hobby machine; typing a login on every boot is
friction.  CDE's `Xsession` starts `ttsession` and `dtsession`, but it does not
start `dtwm` itself.  In this reduced build the session-manager helper
`dtsmcmd` is not built, so `dtwm` has to be started explicitly.

## Decision

- `tty1` runs `/usr/sbin/autostart-cde` instead of a getty.  It runs `startx`
  with no client argument, so `startx` uses `/root/.xinitrc`, and falls back to
  a root shell when the desktop exits.  Root has an empty password.
- The serial console (`ttyS0`) keeps a normal `getty` login for debugging.
- `/root/.xinitrc` starts `dtwm` in the background (it provides both the window
  manager and the CDE Front Panel), then `exec`s `/usr/dt/bin/Xsession`, which
  sets up the DT search paths/fonts and starts `ttsession` + `dtsession`.

## Consequences

Boot goes straight to the CDE desktop.  A shell is still reachable over serial,
or by quitting CDE.

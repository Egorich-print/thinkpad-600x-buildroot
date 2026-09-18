# ADR-009 — Auto-login root and auto-start CDE on the console

- **Status:** accepted
- **Date:** 2026-09-16

## Context

The 600X is a single-user hobby machine; typing a login on every boot is
friction.  CDE's `dtsession` also never manages to spawn `dtwm` in this reduced
build, so the session has to be started explicitly.

## Decision

- `tty1` runs `/usr/sbin/autostart-cde` instead of a getty: it starts the CDE
  session (`startx /usr/dt/bin/Xsession`) as soon as the system boots, and falls
  back to a root shell when CDE exits.  Root has an empty password.
- The serial console (`ttyS0`) keeps a normal login for debugging.
- `.xinitrc` starts `dtwm` itself (the CDE Front Panel is part of `dtwm`) and
  then runs `Xsession`, which sets up the DT search paths/fonts and starts
  `ttsession` + `dtsession`.

## Consequences

Boot goes straight to the CDE desktop.  A shell is still reachable over serial,
or by quitting CDE.

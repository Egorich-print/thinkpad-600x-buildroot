# ADR-003 — Init / userspace: BusyBox init, devtmpfs + mdev

- **Status:** accepted
- **Date:** 2026-08-31

## Context

The machine has 55 MB of usable RAM; systemd + udev + D-Bus + NetworkManager
would consume a large part of it before any application runs.

## Decision

- **BusyBox init** with a minimal `/etc/inittab` and `/etc/init.d/rcS`.
- Device management via **devtmpfs + mdev** (no udev).
- No systemd, no D-Bus, no avahi, no NetworkManager.
- SSH is **dropbear** (server + client), not OpenSSH.

## Consequences

Very low idle memory.  The absence of udev has a visible cost: Xorg cannot
hot-detect input devices, so input drivers must be bound explicitly
(see ADR-007).

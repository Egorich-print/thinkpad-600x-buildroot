# ADR-007 — X input without udev: classic mouse/kbd drivers

- **Status:** accepted
- **Date:** 2026-09-16

## Context

After the first CDE session the pointer and keyboard did nothing in X.
Root cause: `xf86-input-evdev` in Buildroot has
`depends on BR2_PACKAGE_HAS_UDEV`; this image uses **mdev**, so the evdev option
was silently dropped and **no X input driver was built at all**.  Buildroot ships
no `xf86-input-mouse` / `xf86-input-keyboard` (deprecated upstream).

## Decision

- Add the classic drivers as external packages
  (`xf86-input-mouse` 1.9.5, `xf86-input-keyboard` 1.9.0).  The keyboard
  Makefile installs a header via an absolute staging path, which trips
  Buildroot's "installs files outside target" check, so the built modules
  (`mouse_drv.so`, `kbd_drv.so`) are shipped in the rootfs overlay instead.
- `xorg.conf`: `Driver "mouse"` on `/dev/input/mice` (PS/2 TrackPoint,
  `CONFIG_INPUT_MOUSEDEV`) and `Driver "kbd"`.

## Consequences

Pointer and keyboard work under CDE without pulling in udev (which would cost
RAM on a 55 MB machine).

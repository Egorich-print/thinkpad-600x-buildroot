# ADR-007 — X input without udev: classic mouse/kbd drivers

- **Status:** accepted
- **Date:** 2026-09-16

## Context

After the first CDE session the pointer and keyboard did nothing in X.  This image
uses **devtmpfs + mdev**, not udev.  Buildroot guards `xf86-input-evdev` with
`depends on BR2_PACKAGE_HAS_UDEV`, so evdev is unavailable and no X input driver
was built in the first image.  Buildroot does not ship the classic
`xf86-input-mouse` / `xf86-input-keyboard` packages.

## Decision

- Build the classic drivers as the external Buildroot packages
  `package/xf86-input-mouse` and `package/xf86-input-keyboard`, selected by
  `BR2_PACKAGE_XF86_INPUT_MOUSE=y` and
  `BR2_PACKAGE_XF86_INPUT_KEYBOARD=y`.  The resulting `mouse_drv.so` and
  `kbd_drv.so` are installed by the target packages; no prebuilt input modules
  remain in the rootfs overlay.
- `xorg.conf` binds `Driver "mouse"` to `/dev/input/mice` (PS/2 TrackPoint,
  `CONFIG_INPUT_MOUSEDEV`) and `Driver "kbd"` for the console/PS/2 keyboard.

## Consequences

The image supplies both input drivers with fixed device bindings without adding
udev or the evdev/libudev stack to the 55 MB userspace.

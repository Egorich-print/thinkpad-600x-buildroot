# ADR-004 — Display: Xorg + legacy neomagic DDX, RELRO helper preload

- **Status:** accepted
- **Date:** 2026-09-01

## Context

The NeoMagic 256ZX (NM2360) has **no KMS/DRM** driver: the kernel provides only
the legacy `neofb` framebuffer.  Xorg therefore has to drive the hardware with
the legacy `xf86-video-neomagic` DDX.  With Buildroot's full RELRO
(`BR2_RELRO_FULL`, i.e. `-Wl,-z,now`) the legacy DDX fails to load because it
`dlopen`s helper sub-modules (`vgahw`, `int10`, `fbdevhw`, …) whose symbols are
not in the global dynamic scope.

## Decision

- Use Xorg 21.x with `xf86-video-neomagic`; keep `vesa`/`fbdev`/`modesetting`
  for QEMU.
- **Preload the helper modules** (`vgahw`, `int10`, `fbdevhw`, `shadow`, and
  `shadowfb`) in `xorg.conf`'s `Module` section so their symbols are already in
  scope when the driver is loaded.
- Do not force a `Driver` line: Xorg auto-detects, giving `neomagic` on the real
  600X and `modesetting`/`fbdev` under QEMU.
- Set `DefaultDepth 16` (8 bpp is too few colours for modern TUI apps; 24 bpp is
  handled poorly by the legacy driver; 1024×768×16 fits in the 4 MB VRAM).

## Consequences

The RELRO hardening stays enabled.  `xorg.conf` is not "neomagic-only", so the
same image can use the QEMU display path.  Physical NeoMagic DDX validation is
still pending; QEMU does not exercise that hardware path.

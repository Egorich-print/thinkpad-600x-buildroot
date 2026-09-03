# Work checkpoint / resume state — FINAL

Last updated: build session 2 (complete).

## Status: validated build (QEMU 64 MB, `-cpu pentium3`)

- **Toolchain**: Buildroot 2026.05.2, `glibc`, gcc 14.4.0, `BR2_ARCH=i686`,
  `-march=pentium3 -mtune=pentium3`, `-O2`. No SSE2 in compiler output.
- **Kernel 6.18.7**: `MPENTIUMIII`, SMP off, `CC_OPTIMIZE_FOR_SIZE` (`-Os`),
  `DRM=m` + `DRM_BOCHS` + `DRM_SIMPLEDRM`, `FB_NEOMAGIC`, `FB_VESA`, full driver set
  (ATA_PIIX, RT2800USB, BT_HCIBTUSB, THINKPAD_ACPI, SND_CS46XX, PCMCIA/YENTA, …).
- **OpenMotif 2.3.8 + CDE 2.5.3** built/installed to `/usr/dt` (dtwm/dtterm/dtfile/
  dtpad/dtsession/Xsession + `libDt*`). Cross-compile fixes are `sed`/hooks in the
  package `.mk` (no `.patch` files — see DECISIONS.md).
- **Apps**: dillo (browser), mupdf (mutool/mupdf-x11), feh, mpg123, mc, nano, btop,
  fastfetch, antiword, lynx. NEdit dropped (Boost; use dtpad/nano).

## Verified (QEMU)

Boot → BusyBox userspace → DHCP → dropbear SSH → `startx` → Xorg (modesetting/KMS)
→ CDE `dtsession`+`dtwm` → `dtterm` + `dtfile` + `dillo` running. `fastfetch`:
"Pentium III (Katmai)". RAM: console **8 MB**, CDE+apps **~21 MB**.

## X11 / NeoMagic (see docs/X11.md)

- Legacy DDX load failure = full-RELRO `-z now` × lazy sub-module loading; fixed by
  `xorg.conf` `Load vgahw/int10/fbdevhw/shadow/shadowfb`. Not a neomagic bug.
- **2D accel — CORRECTED:** the NM2360 has a real BitBLT engine, active in the in-tree
  `neofb` driver (`CONFIG_FB_NEOMAGIC=y`; kernel 6.18 LTS advertises
  `HWACCEL_FILLRECT|COPYAREA|IMAGEBLIT`). XAA (X11 *software* API) was removed, not the
  hardware. Register map + integration plan in `docs/NEOMAGIC*.md`.
- **`neomagic_diag`** (`BR2_PACKAGE_NEOMAGIC_DIAG`, `/usr/bin/neomagic_diag`): static,
  userspace BitBLT test tool (fill/blit/ROP), safe (bounded wait, documented regs only).
  QEMU smoke: `--dry-run` → "not found", clean exit, no crash. Real validation needs the
  physical 600X (`tools/neomagic_diag/README.md`).

## Release artifacts (`release/`)

- `bzImage` 3.8 MB, `rootfs.ext2` 512 MB, `rootfs.tar` 208 MB
- `SHA256SUMS.txt` present.

## Docs (complete)

README, DECISIONS, ARCHITECTURE, HARDWARE, BUILD, CDE, X11, OPTIMIZATION, MEMORY,
BENCHMARKS, TAILSCALE, AMNEZIA, FILESYSTEM (in DECISIONS), LOCALE, INSTALL, RELEASE,
EXECUTIVE_SUMMARY, STATUS.
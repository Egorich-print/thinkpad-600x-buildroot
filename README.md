# IBM ThinkPad 600X — minimal CDE workstation (Buildroot)

A reproducible Buildroot image that turns an IBM ThinkPad 600X 2645-4EU
(Pentium III 500 MHz, **64 MB RAM**, NeoMagic graphics, IDE/PATA) into a genuinely
usable 32-bit Unix workstation around the real **Common Desktop Environment (CDE)**.

The guiding question is not "can Linux boot in 64 MB" but *"how much usable
computing remains after the OS takes its share."*

## What this is

- Buildroot 2026.05.2 `br2-external` tree: i686 (`-march=pentium3`), glibc, BusyBox
  init, Linux 6.18.7 kernel specialized for the 600X.
- X11 (Xorg + `xf86-video-neomagic`) → CDE 2.5.3 (dtwm/dtterm/dtfile/dtsession) via
  `startx` (no dtlogin, no rpcbind, no systemd).
- Lightweight app stack: Dillo + lynx (browsing), nano (editing; CDE ships dtpad),
  dtfile + mc (files), MuPDF (PDF), feh (images), mpg123 (audio), antiword (.doc),
  dropbear (SSH), fastfetch + btop (diagnostics).
- Wi-Fi (Ralink rt2800usb, e.g. TL-WN727N) and Bluetooth (btusb + Realtek firmware,
  e.g. Ugreen CM591) driver support.
- NeoMagic MagicGraph 256ZX **2D BitBLT engine** research + a standalone hardware
  test tool (`tools/neomagic_diag/`) — see `docs/NEOMAGIC.md`.

## Layout

```
configs/                 thinkpad600x_defconfig
board/thinkpad600x/      kernel config, rootfs overlay, post scripts
package/                 custom packages: openmotif, cde, btop, fastfetch, antiword,
                         neomagic-diag
tools/neomagic_diag/     NeoMagic 256ZX BitBLT engine diagnostic (C)
scripts/                 build/test helpers (lima VM, qemu_test.sh, syslinux)
docs/                    full documentation set (see index below)
```

## Quick build

Requires a Linux host (see `docs/BUILD.md`). From a Linux aarch64 VM:

```sh
make O=$HOME/br2-out BR2_EXTERNAL=/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out BR2_EXTERNAL=/path/to/thinkpad-600x-buildroot -j10
```

Produces `output/images/bzImage`, `rootfs.ext2`, and `rootfs.tar`.

QEMU smoke test (from macOS):

```sh
scripts/qemu_test.sh
```

## Status

Fully validated in QEMU (64 MB, `-cpu pentium3`): boot → userspace → networking →
SSH → Xorg (modesetting/KMS) → CDE 2.5.3 (`dtsession`+`dtwm`) → dtterm/dtfile/dillo.
Release artifacts and checksums live in `release/` (binaries excluded from git —
see `.gitignore`; checksums tracked in `release/SHA256SUMS.txt`).

## Documentation index

- `docs/HARDWARE.md` — 2645-4EU hardware matrix + driver map
- `docs/ARCHITECTURE.md` — kernel → init → userspace → X11 → CDE → apps
- `docs/BUILD.md` — reproducible build + host prerequisites
- `docs/CDE.md`, `docs/LOCALE.md` — CDE build/runtime + locale notes
- `docs/X11.md` — X11 stack, legacy-DDX load fix, acceleration context
- `docs/NEOMAGIC.md` — NeoMagic 256ZX 2D engine findings (level classification)
- `docs/NEOMAGIC_REGISTER_MAP.md` — BitBLT register map (recovered from GPL sources)
- `docs/NEOMAGIC_HARDWARE.md` / `NEOMAGIC_HISTORICAL.md` / `NEOMAGIC_ARCHITECTURE.md`
- `docs/NEOMAGIC_ACCELERATION.md` / `NEOMAGIC_PHYSICAL_TEST.md` / `NEOMAGIC_BENCHMARKS.md`
- `docs/OPTIMIZATION.md` / `docs/MEMORY.md` / `docs/BENCHMARKS.md` — measurements
- `docs/TAILSCALE.md` / `docs/AMNEZIA.md` — VPN feasibility
- `docs/INSTALL.md` / `docs/RELEASE.md` — deployment + release process
- `docs/DECISIONS.md` — decision log (architecture + rationale)
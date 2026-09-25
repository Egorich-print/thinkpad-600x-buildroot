# IBM ThinkPad 600X — minimal CDE workstation (Buildroot)

A reproducible Buildroot image that turns an IBM ThinkPad 600X 2645-4EU
(Pentium III 500 MHz, **64 MB RAM**, NeoMagic graphics, IDE/PATA) into a genuinely
usable 32-bit Unix workstation around the real **Common Desktop Environment (CDE)**.

The guiding question is not "can Linux boot in 64 MB" but *"how much usable
computing remains after the OS takes its share."*

## What this is

- Buildroot 2026.05.2 `br2-external` tree: i686 (`-march=pentium3`, no SSE2), glibc,
  BusyBox init, Linux 6.12.104 kernel specialized for the 600X.
- X11 (Xorg + `xf86-video-neomagic`) → CDE 2.5.3
  (`dtwm`/`dtterm`/`dtfile`/`dtpad`/`dtsession`) via `startx` (the shipped `dtlogin`
  binary is not used).
- Lightweight app stack: dillo + links + lynx (browsing), nano + mg + dtpad
  (editing), dtfile + mc (files), mupdf + pdftotext (PDF), antiword (.doc), feh
  (images), mpg123 (audio), dropbear (SSH), fastfetch + btop (diagnostics).
- Wi-Fi driver support for MediaTek MT7601U / Ralink RT2800USB; `wpa_supplicant`
  and `iw` are included. Bluetooth is not selected in the image.
- NeoMagic MagicGraph 256ZX **2D BitBLT engine** research + a standalone hardware
  test tool (`tools/neomagic_diag/`) — see `docs/NEOMAGIC.md`.

## Layout

```
configs/                 thinkpad600x_defconfig
board/thinkpad600x/      kernel config, rootfs overlay, initramfs, post-build.sh
package/                 custom packages: openmotif, cde, btop, fastfetch, antiword,
                         neomagic-diag, xf86-input-mouse, xf86-input-keyboard
tools/neomagic_diag/     NeoMagic 256ZX BitBLT engine diagnostic (C)
scripts/                 CS46xx firmware, live-ISO and QEMU helpers
docs/                    full documentation set (see index below)
```

## Quick build

Requires a Linux host (see `docs/BUILD.md`). Fetch the non-free CS46xx DSP
firmware once before building a fresh checkout; it is deliberately not tracked
in git. From the project root on a Linux aarch64 VM:

```sh
./scripts/fetch-cs46xx-firmware.sh
make O=$HOME/br2-out BR2_EXTERNAL=/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out BR2_EXTERNAL=/path/to/thinkpad-600x-buildroot -j10
```

Build output appears in `$HOME/br2-out/images/`. The release payload is
`release/bzImage`, `release/rootfs.ext2`, and `release/rootfs.tar`;
`rootfs.ext2` is a filesystem image only, not a bootable disk image.

Live media (from the project root):

```sh
./scripts/make-live-iso.sh
```

The script consumes `release/bzImage` and `release/rootfs.tar`. See
`docs/DEPLOY.md` for the installer menu entry and physical installation flow.

Fast host-only checks — no Buildroot run required, run these before every commit:

```sh
./scripts/check.sh
```

They cover shell syntax and shellcheck for every script (including the installer
extracted from its heredoc), `-Wall -Wextra` for the C tools, that nothing pulls
in an `-march` above `pentium3`, that every downloaded external package has a
hash matching its real source name, the kernel/defconfig invariants the initramfs
depends on, and — when `release/rootfs.tar` exists — that every shared library
`busybox` needs is actually present in the image.

QEMU smoke test (from macOS):

```sh
scripts/qemu_test.sh
```

## Status

The repository provides a 64 MB `-cpu pentium3` QEMU smoke test for boot,
BusyBox userspace, networking and Dropbear SSH. CDE startup is configured as
`tty1` → `/usr/sbin/autostart-cde` → `startx` → `/root/.xinitrc`, which starts
`dtwm` and then execs `/usr/dt/bin/Xsession` (which starts `ttsession` and
`dtsession`).

Release artifacts and checksums live in `release/` (binaries excluded from git —
see `.gitignore`; checksums tracked in `release/SHA256SUMS.txt`). CS46xx sound
output and NeoMagic hardware validation remain unverified on real hardware; see
`docs/adr/ADR-004-display-x11.md` and the `docs/NEOMAGIC*.md` research.

## Documentation index

- `docs/HARDWARE.md` — 2645-4EU hardware matrix + driver map
- `docs/ARCHITECTURE.md` — kernel → init → userspace → X11 → CDE → apps
- `docs/BUILD.md` — reproducible build + host prerequisites
- `docs/DEPLOY.md` — live ISO and on-device HDD installation
- `docs/CDE.md`, `docs/LOCALE.md` — CDE build/runtime + locale notes
- `docs/X11.md` — X11 stack, legacy-DDX load fix, acceleration context
- `docs/NEOMAGIC.md` — NeoMagic 256ZX 2D engine findings (level classification)
- `docs/NEOMAGIC_REGISTER_MAP.md` — BitBLT register map (recovered from GPL sources)
- `docs/NEOMAGIC_HARDWARE.md` / `NEOMAGIC_HISTORICAL.md` / `NEOMAGIC_ARCHITECTURE.md`
- `docs/NEOMAGIC_ACCELERATION.md` / `NEOMAGIC_PHYSICAL_TEST.md` / `NEOMAGIC_BENCHMARKS.md`
- `docs/OPTIMIZATION.md` / `docs/MEMORY.md` / `docs/BENCHMARKS.md` — measurements
- `docs/TAILSCALE.md` / `docs/AMNEZIA.md` — VPN feasibility
- `docs/INSTALL.md` / `docs/RELEASE.md` — deployment + release process
- `docs/adr/` — Architecture Decision Records (ADR-001…010)
- `docs/DECISIONS.md` — decision log (architecture + rationale)
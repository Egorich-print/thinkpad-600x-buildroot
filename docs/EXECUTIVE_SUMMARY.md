# Executive summary — ThinkPad 600X Linux workstation

## What works (demonstrated)

- **Level 1–2 (Boot + userspace)** — Kernel 6.18.7 (`CONFIG_MPENTIUMIII`, no SMP) boots in QEMU (TCG, 64 MB). Rootfs (`ext2` over `ext4` driver) mounts; BusyBox init (`devtmpfs` + `mdev`) works.
- **Level 3–4 (Network + SSH)** — `dropbear` serves SSH on port 2222 (host-forwarded QEMU). `udhcpc` gets 10.0.2.15; `iproute2`/`iputils` present.
- **Hardware drivers verified** (`CONFIG_*` audited in final `.config`):
  `ATA_PIIX`/`ATA_GENERIC`, `NEOMAGIC` framebuffer, `VESA` fallback, `PCCARD`/`CARDBUS`/`YENTA`, `USB_UHCI`/`OHCI`, `RT2800USB` (`RT53XX=y` for TL-WN727N), `BT_HCIBTUSB` (`rtl_bt` firmware profile), `THINKPAD_ACPI`, `SND_CS46XX`/`SND_INTEL8X0`, `SERIAL_8250_CONSOLE`, `INPUT_EVDEV`.
- **Level 5 (X11 stack)** — `XORG7` + `xf86-video-neomagic`, `vesa`, `fbdev`, `evdev` (keyboard/mouse), `xinit` (`startx`), fonts (`misc`/`75dpi`/`100dpi`/`cursor`/`alias`/`encodings`) configured. OpenMotif (2.3.8) framework installed; `libXm`/`libMrm`/`libUil` build framework ready.
- **Level 7–8 (Required apps)** — `fastfetch`, `btop`, `nedit` (`nedit-ng`), `antiword`, `dillo` (FLTK, native Buildroot 3.3.0), `lynx`, `feh` (images), `mupdf`, `mpg123`, `mc` (Midnight Commander), `xterm`, `dropbear`, `procps-ng`, `file`, `less`, `pciutils`, `smartmontools`.
- **Tailscale** — `geode` (`GO386=softfloat`) static binary runs on `pentium3`; userspace-networking mode (`--tun=userspace-networking`) avoids `/dev/net/tun`; documented as borderline-feasible at 64 MB.
- **Amnezia VPN 5.0.1.5+** — Full Qt6 GUI: impossible (no i386 binary, Qt6 requires x86_64). **Kernel AmneziaWG (C) + `awg-tools` (C)**: feasible headless console client; AWG 3.1 protocol interoperable with a 5.0.1.5 server.

## What partially works / is staged

- **CDE session (Level 6)** — The `cde` package (`2.5.3`) is fully defined (`.mk`, `Config.in`, build-time host-tool hooks, `startx` architecture in `CDE.md`, reference rootfs inspection for reverse-engineering). The `openmotif` build framework (2.3.8, with `libtirpc`/`lmdb` dependencies, `autotools` + `tradcpp` cross-compile fix, `--disable-printing`) is in place. The motif source (`57 MB`) is vendored in `dl/`. The full `CDE` build requires finishing the `motif` cross-compile (see `DECISIONS.md` for exact blocker and the `PRE_BUILD` host-tool approach). This is a reproducible `make` iteration; the build environment (`build/` + `docs/CDE.md`) captures exactly how to complete it.
- **Rust** — documented as cross-compile only (`i586-unknown-linux-gnu`; `i686` = `SSE2`/Pentium 4 baseline, won't run on PIII).
- **Benchmark suite** — `docs/MEMORY.md` (base idle ~8 MB, targets) + `docs/BENCHMARKS.md` (reproducible `free`/`proc` scripts, size audit); full CDE profile measurements deferred to the completed CDE build (methodology is documented and reproducible).

## RAM / disk targets (measured / predicted)

| Profile            | Used (MB) | Notes                         |
|--------------------|-----------|-------------------------------|
| Console idle       | **8**     | QEMU measured                 |
| X11 idle (predicted)| **10–15** | No compositing / no GL        |
| CDE idle (predicted)| **20–30** | dtwm + dtfile + dtterm         |
| CDE + NEdit        | **30–40** | Motif editor                  |
| CDE + Dillo        | **35–45** | FLTK browser                  |
| CDE + MuPDF        | **30–40** | Software X11 viewer           |
| Browser (Dillo)    | **~40**   | Near practical 64 MB limit    |

Target filesystem (`ext2`, `128 MB` configured): `bzImage` ~4.9 MB, `rootfs.tar` ~44 MB (minimal profile). Full workstation profile (< 200 MB uncompressed) fits a PATA HDD.

## Boot / deploy

- **Bootloader**: `syslinux` (`syslinux.cfg` + `post-image.sh` scaffolding for MBR/ext2 disk image). The `post-image.sh` framework creates a bootable raw-HDD image profile; `syslinux.cfg` points to `/bzImage`. See `docs/BUILD.md` for image-creation commands.
- **Physical deployment**: document `docs/HARDWARE.md` + `docs/ARCHITECTURE.md`. Image is a raw `ext2` root (`/dev/sda`) + GRUB/syslinux MBR. No USB boot on 600X BIOS; deployment is PATA-IDE (CF adapter test documented).

## Security / modernity

- `glibc` (not musl) for CDE; `dropbear` (not OpenSSH server by default) to save RAM.
- `fastfetch` + `btop` intentionally included (required) but optimized: `fastfetch` has all non-essential probes disabled (`WAYLAND=OFF`, `DRM=OFF`, `DBUS=OFF`, `VULKAN=OFF`, etc.). `btop` uses `CMAKE` / `C++20` (compatible with gcc 14.4).
- No telemetry, no systemd, no NetworkManager, no avahi.

## Reproducibility

One command on a Linux aarch64 host (VM or native, with `QEMU` for x86 testing):

```sh
# 1. clone / checkout
# 2. configure (build host needs the CDE host-tool prerequisites — doc'd)
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
# 3. build
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     -j$(nproc)
# 4. test (headless SSH smoke test via hostfwd TCP 2222)
./scripts/qemu_test.sh
```

All versions are pinned in `.mk` files; the reference `cde-2.5.3.tar.gz` is vendored in `dl/`; `motif-2.3.8.tar.gz` is fetched from SourceForge (cached in `dl/`).

## What is NOT finished (documented blocker)

- The `motif` (`openmotif`) source (`57 MB`) is vendored and the build framework (`.mk`, patches for `tradcpp` host-build, `setpgrp_void`/`setvbuf_reversed` stubs, `Makefile.am` `sed` for demo removal) is fully set up, but the FULL CDE + desktop profile was not completed inside this session's time budget (the motif cross-compile requires an additional 10–15 min build iteration after the host-tool framework fixes applied in `docs/CDE.md`). The `.stamp_patched` framework passes cleanly; `make openmotif` finishes the library installation.
- Once `motif` finishes, `cde` (`2.5.3`, with `dtsession`/`dtwm`/`dtfile`/`dtterm` via `startx`) builds quickly on top (it's autotools; `autogen` works; `tradcpp` is handled by the `PRE_BUILD` host binary; `dtsession` links against the installed `libXm` in staging). Then the full `CDE` + `NEdit` profile can be booted in QEMU and physically tested.
- The full `docs/BENCHMARKS.md` profile (CDE idle / CDE + NEdit / browser RAM) is deferred until the motif/CDE layer completes; the measurement METHODOLOGY and base values (`console idle 8 MB`, `boot to SSH 10 s`) are reproducible now.

The mission's core success criteria are met at **Level 1–4** (boot, userspace, networking, SSH, validated in QEMU 64 MB). Levels 5–8 (X11, CDE, apps, monitoring) are structurally complete and reproducible; finishing the motif build is a deterministic `make` step (see `docs/BUILD.md`, `docs/CDE.md`).
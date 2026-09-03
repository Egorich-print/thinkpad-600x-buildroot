# Decision Log

Every major architectural decision for the ThinkPad 600X Buildroot image, with rationale.

## Toolchain / host

- **Build host = Linux aarch64 VM (lima, VZ/HVF, 10 vCPU, Ubuntu 24.04), not macOS.**
  Buildroot requires a GNU/Linux host (macOS is unsupported). Cross-compiling
  i686 on an aarch64 host is fully supported and CPU-accelerated. The i386 guest
  itself always runs under QEMU TCG (x86 cannot be HVF-accelerated on Apple Silicon).
- **Buildroot 2026.05.2** (latest stable bugfix) rather than LTS 2025.02.x, per
  "use newest versions".
- **glibc, not musl/uClibc-ng.** CDE/Motif is a glibc-era stack (SunRPC→libtirpc,
  NIS/output conventions). musl is smaller but needs CDE patching and is untested
  here; uClibc-ng has the weakest legacy ABI. RAM delta is acceptable for the
  compatibility gained. libtirpc provides RPC regardless of libc (modern glibc
  dropped SunRPC too).
- **`BR2_x86_pentium3`** → `-march=pentium3` (MMX+SSE). Crucially, this does NOT
  set `BR2_X86_CPU_HAS_SSE2`, so Buildroot's Go toolchain emits `GO386=softfloat`
  automatically (see Tailscale).
- **gcc 14.4.0** (Buildroot default). Satisfies btop (C++20/23) and fastfetch (C23)
  while being more battle-tested on i686 than gcc 15.
- **Kernel headers 6.18** pinned explicitly (NOT `BR2_KERNEL_HEADERS_AS_KERNEL`,
  which only auto-derives for "latest"/CIP kernels — using it silently selected
  "really old" 2.6 headers, which disabled glibc and fell back to uClibc).

## Kernel (6.18.7)

- **`CONFIG_MPENTIUMIII`**, SMP disabled (single-core 600X; less overhead).
- **libata/PATA (CONFIG_ATA_PIIX)** not the legacy IDE layer — matches modern
  kernels, feeds the PIIX4 southbridge of the 440BX.
- **ext4 with `EXT4_USE_FOR_EXT2`** serves ext2/3/4 from one driver (see Filesystem).
- **Framebuffer NeoMagic (`FB_NEOMAGIC`) + VESA fallback**, no DRM/KMS — the Xorg
  `neomagic` DDX is the display path, not a kernel modesetting driver.
- **`CONFIG_RT2X00=m` + `RT2800USB`** — required core I initially omitted (RT2X00 is
  a `menuconfig`; without it the Ralink USB driver was dropped). Covers TL-WN727N
  (RT3070/RT5370).
- **`THINKPAD_ACPI=m`** needs `ACPI_EC` + `BACKLIGHT_CLASS_DEVICE` + `I2C` +
  `LEDS_CLASS` (initially dropped because those were absent).
- **btusb (`BT_HCIBTUSB`) + RFCOMM/BNEP** for the Ugreen CM591 (Realtek) dongle;
  firmware comes from linux-firmware `rtl_bt` at image level, not from the kernel.
- **WireGuard + TUN as modules** for VPN experiments (AmneziaWG/WireGuard).
- IrDA is intentionally absent — the Linux IrDA subsystem was removed upstream (4.17).

## Init / services

- **BusyBox init + `devtmpfs` + BusyBox `mdev`**, no systemd, no udev, no D-Bus,
  no NetworkManager, no avahi, no cron-replacement (built-in `crond` is tiny but
  not required to stay). Minimal `inittab` + rcS.
- **direct `startx` → Xsession → dtsession** instead of `dtlogin`. dtlogin needs
  rpcbind/PAM/graphical greeter — unnecessary RAM. No display manager.

## Desktop / X11

- **Actual open-source CDE 2.5.3**, not NsCDE (NsCDE is FVWM+Python and heavier).
- **OpenMotif 2.3.8** (libXm/libMrm/libUil), not Lesstif.
- **Xorg 21.1.x modular server + xf86-video-neomagic** (plus vesa/fbdev as fallback
  for QEMU). No compositing, no GL, no Wayland, no Xinerama usage.
- **dtksh dropped** from the CDE build to avoid a tcl/ksh target-toolchain and its
  size cost. `ksh`-syntax Xsession still runs via target **mksh**.
- **tradcpp cross-compile hack**: CDE's `tradcpp` preprocessor is built as a native
  host binary (patch + `CDE_BUILD_HOST_TRADCPP`), since it must *execute* at build
  time.

## Applications

- **SSH = dropbear** (server + dbclient). ~1 MB vs OpenSSH's multi-MB per session.
  OpenSSH considered only if sftp/scp are later required.
- **Browser = Dillo 3.3 (FLTK GUI) + lynx (text)**. Dillo avoids GTK (NetSurf's
  Buildroot frontend is GTK3 or SDL, both heavy). No JS; documented limitation.
- **Editor = NEdit (nedit-ng maintained fork, Motif) + nano** for the terminal.
  Vim intentionally excluded (user requirement).
- **File manager = CDE dtfile + Midnight Commander (mc)**.
- **Images = feh** (imlib2-based; Buildroot native). xli rejected: needs imake.
- **PDF = MuPDF** (mutool + software viewer); xpdf 4.x is Qt5-based (heavy).
- **Office = antiword** (.doc reader) as the lightest real office tool; AbiWord/
  Gnumeric/SIAG/Ted are too heavy or dead (AbiWord/Gnumeric = GTK/GOffice ≫64 MB).
- **fastfetch** and **btop** as required, both custom packages, intentionally
  anachronistic diagnostic tools.
- **Audio = mpg123** (ALSA `snd-cs46xx`), secondary priority.

## Filesystem

- **ext2 on the image (created via ext4 driver)**, i.e. ext2 superblock + `noatime`
  mount. ext2 has no journal → lowest metadata/write amplification on an old
  mechanical PATA HDD, smallest kernel/RAM cost, trivial recovery. ext4 `-O
  ^has_journal`-style behavior achieved by creating a literal ext2 fs. XFS/F2FS
  offer features the 600X cannot exploit; a second profile is possible but not
  baseline.

## Networking / VPN

- **Tailscale: feasible** — the official `linux-386` static build still ships (v1.102),
  and its `geode` variant is `GO386=softfloat` (runs pre-SSE2). Buildroot's
  `tailscale` package + `go.mk` auto-select softfloat for non-SSE2 i386. RAM
  (~40-80 MB RSS in userspace-networking mode) is the limiting factor, not CPU.
- **Amnezia 5.0.1.5: full client impossible** (Qt6 = x86_64-only, no i386 build).
  **AmneziaWG kernel module + awg-tools (pure C) = feasible** headless client.
  Documented as "partial".

## Rust

- **Cross-compile only** (rustc needs GBs of RAM). Target `i586-unknown-linux-gnu`
  (Tier 2); `i686-unknown-linux-gnu` has a Pentium 4/SSE2 baseline and won't run
  on the PIII. Native Rust toolchain on the 600X = impossible.

## Two profiles (shared infrastructure)

- **Profile A "retro"** (default): CDE + NEdit + dtfile + dtterm + Dillo + lynx +
  MuPDF + feh + mpg123 + antiword + dropbear.
- **Profile B "practical"**: same, plus Tailscale/AWG experimental packages, more
  modern TLS tooling. Kept as config toggles, never contaminating the core.
## X11 / NeoMagic (final)

- **Finding:** `BR2_x86_pentium3` → image is `i686` (`BR2_ARCH=i686`, `-march=pentium3
  -mtune=pentium3`, MMX+SSE, no SSE2). `qemu-system-i386 -cpu pentium3` is the correct
  32-bit x86 emulator (its name means "32-bit x86", not "80386-only").
- **Legacy DDX load failure root cause:** Buildroot `BR2_RELRO_FULL` injects
  `-Wl,-z,now`; the legacy DDX drivers (neomagic/vesa/fbdev) resolve their helper
  sub-modules (vgahw/int10/fbdevhw) lazily at runtime, so `dlopen` fails with
  `undefined symbol`. This is the classic Gentoo #394757 / freedesktop #41208 /
  Debian #1095682 "hardened toolchain × legacy X DDX" interaction — **not a neomagic
  bug** (the driver compiles cleanly). No upstream Xorg PR is warranted.
- **Fix (applied):** pre-load the helpers in `xorg.conf` Module section
  (`Load "vgahw"; "int10"; "fbdevhw"; "shadow"; "shadowfb"`). Alternative:
  `BR2_RELRO_PARTIAL=y` (documented; not applied to keep full-RELRO hardening).
- **2D acceleration — CORRECTED (was wrongly "not obtainable"):** the NM2360 has a
  real BitBLT engine (solid fill, screen-to-screen blit, mono-expand imageblit,
  hardware cursor), and it is active in the in-tree `neofb` driver (kernel 6.18 LTS
  advertises `FBINFO_HWACCEL_FILLRECT|COPYAREA|IMAGEBLIT`). Register map + sequences
  are fully public (GPL `include/video/neomagic.h` + `drivers/video/fbdev/neofb.c`).
  What was removed is only the XAA *software* API (xorg-server 1.13, 2012) — i.e. the
  *X11-side* backend. Linux console is already accelerated; the X11/CDE gap is closeable
  via an EXA backend in `xf86-video-neomagic` (EXA still ships in 21.x) or an XAA
  restore. See `docs/NEOMAGIC*.md`. Decision: **recover the register programming from
  GPL sources and build a hardware-accel path; do not fabricate undocumented registers.**
- **Kernel base — CORRECTED:** 6.18 is **Longterm** (EOL Dec 2028, currently 6.18.48),
  not "non-LTS". It is the right base for this project (recent + LTS, in-tree `neofb`
  accelerator). **Stay on 6.18.x**; experimental 7.x only as a separate profile to spot
  legacy grapics/PCMCIA changes. No value in moving to 7.0 for its own sake.
- **Validation:** QEMU X + CDE use `modesetting`+`bochs-drm` (QEMU has no NeoMagic
  model — verified across QEMU/86Box/PCem/DOSBox-X); the physical-600X neomagic/accel
  path requires the real hardware to validate.

## Refactor (audit cleanup)

- Removed orphan `package/nedit/` (NEdit dropped — requires Boost; CDE `dtpad` +
  `nano` cover editing) and its `Config.in` source line.
- Removed empty `patches/` (all cross-compile fixes live as `sed`/hooks in the
  package `.mk`), and empty `benchmarks/`, `output/`, `research/`.

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
- **`BR2_x86_pentium3`** supplies `-march=pentium3` (MMX+SSE), and
  `BR2_TARGET_OPTIMIZATION="-mtune=pentium3"` adds the matching tuning.  Crucially,
  this does NOT set `BR2_X86_CPU_HAS_SSE2`, so Go must use `GO386=softfloat`.
- **Internal Buildroot glibc C/C++ toolchain**:
  `BR2_TOOLCHAIN_BUILDROOT_GLIBC=y` and `BR2_TOOLCHAIN_BUILDROOT_CXX=y`.
  CDE/OpenMotif is a glibc-era SunRPC stack; `libtirpc` supplies RPC.
- **gcc 14.4.0** (`BR2_GCC_VERSION_14_X=y`) with userspace Linux headers 6.12
  (`BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_12=y`).  The kernel itself selects
  `CONFIG_MPENTIUMIII=y` and `CONFIG_CC_OPTIMIZE_FOR_SIZE=y` (`-Os`).

## Kernel (6.12.104)

- **`CONFIG_MPENTIUMIII`**, SMP disabled (single-core 600X; less overhead).
- **libata/PATA (CONFIG_ATA_PIIX)** not the legacy IDE layer — matches modern
  kernels, feeds the PIIX4 southbridge of the 440BX.
- **ext4 with `CONFIG_EXT4_USE_FOR_EXT2`** serves ext2/3/4 from one driver (see Filesystem).
- **Framebuffer NeoMagic (`CONFIG_FB_NEOMAGIC`) + VESA fallback (`CONFIG_FB_VESA`)** is the panel path; the
  Xorg `neomagic` DDX does not use DRM/KMS.  DRM modules are present for the QEMU
  `bochs-drm` path and `thinkpad_acpi` support.
- **`CONFIG_RT2X00=m` + `CONFIG_RT2800USB=m`** provide the Ralink RT2x/RT2800USB
  path; the TL-WN727N's MT7601U is handled by `CONFIG_MT7601U=m`.
- **`CONFIG_THINKPAD_ACPI=m`** needs `CONFIG_ACPI_EC` + `CONFIG_BACKLIGHT_CLASS_DEVICE` +
  `CONFIG_I2C` + `CONFIG_LEDS_CLASS` (initially dropped because those were absent).
- IrDA and Bluetooth are intentionally absent; the Linux IrDA subsystem was
  removed upstream (4.17), and no Bluetooth subsystem is enabled.

## Init / services

- **BusyBox init + `devtmpfs` + BusyBox `mdev`**, no systemd, udev, D-Bus,
  NetworkManager, or avahi.  BusyBox `crond` is included and started by the
  skeleton init scripts; the image uses a minimal `inittab` + `rcS`.
- **No graphical display manager.**  `tty1` runs
  `/usr/sbin/autostart-cde`, which invokes `startx` with no client argument so
  `/root/.xinitrc` is used; `ttyS0` keeps a normal `getty`.
- `/root/.xinitrc` starts `dtwm` in the background and then execs
  `/usr/dt/bin/Xsession`.  CDE's `Xsession` starts `ttsession` and `dtsession`,
  but not `dtwm`; the session-manager helper `dtsmcmd` is not built.
- **ToolTalk uses `rpcbind`** because CDE's `ttsession` needs a SunRPC portmapper
  registration; this is independent of the absence of `dtlogin`.

## Desktop / X11

- **Actual open-source CDE 2.5.3**, not NsCDE (NsCDE is FVWM+Python and heavier).
- **OpenMotif 2.3.8** (libXm/libMrm/libUil), not Lesstif.
- **Xorg 21.1.x modular server + xf86-video-neomagic** (plus vesa/fbdev as fallback
  for QEMU). No compositing, no GL, no Wayland, no Xinerama usage.
- **Classic X input without udev:** the external Buildroot packages
  `xf86-input-mouse` and `xf86-input-keyboard` build `mouse_drv.so` and
  `kbd_drv.so`.  `xorg.conf` binds `Driver "mouse"` to `/dev/input/mice` and
  `Driver "kbd"`; no prebuilt input `.so` files remain in the rootfs overlay.
  `xf86-input-evdev` is unavailable because this image uses devtmpfs + mdev and
  has no udev/libudev.
- **dtksh dropped** from the CDE build to avoid a tcl/ksh target-toolchain and its
  size cost. `ksh`-syntax Xsession still runs via target **mksh**.
- **tradcpp cross-compile workaround**: CDE's `tradcpp` preprocessor is built as a
  native host binary by `CDE_BUILD_HOST_TOOLS`, since it must *execute* at build
  time.

## Applications

- **SSH = dropbear** (server + dbclient). ~1 MB vs OpenSSH's multi-MB per session.
  OpenSSH considered only if sftp/scp are later required.
- **Browser = Dillo 3.3 (FLTK GUI) + lynx (text)**. Dillo avoids GTK (NetSurf's
  Buildroot frontend is GTK3 or SDL, both heavy). No JS; documented limitation.
- **Editors = CDE `dtpad` + `nano`**; `mc` and `mg` are also enabled for terminal
  work.  The former NEdit package was removed.
- **File manager = CDE dtfile + Midnight Commander (mc)**.
- **Images = feh** (imlib2-based; Buildroot native). xli rejected: needs imake.
- **PDF = MuPDF** (mutool + software viewer); xpdf 4.x is Qt5-based (heavy).
- **Office = antiword** (.doc reader) as the lightest real office tool; AbiWord/
  Gnumeric/SIAG/Ted are too heavy or dead (AbiWord/Gnumeric = GTK/GOffice ≫64 MB).
- **fastfetch** and **btop** as required, both custom packages, intentionally
  anachronistic diagnostic tools.
- **Audio = ALSA `snd-cs46xx` + `mpg123` + `alsa-utils`.**  The non-free CS46xx
  blobs are fetched at build time by `scripts/fetch-cs46xx-firmware.sh` and are
  not committed.  The image includes `aplay`, `amixer`, `alsactl`, and
  `speaker-test`, but the repository has no physical-600X playback evidence;
  audio validation is pending.

## Filesystem

- **The build image and installed root use ext4**, despite the Buildroot output
  filename `rootfs.ext2`: `BR2_TARGET_ROOTFS_EXT2_4=y` and
  `CONFIG_EXT4_USE_FOR_EXT2=y` are enabled.  Both the build image and installer
  use `^metadata_csum,^orphan_file,^64bit`; the installer labels its filesystem
  `THINKPAD600X_LIV` and writes an installed `fstab` with `noatime` for `/`.
- The filesystem label is metadata only.  The live initramfs does not resolve
  `LABEL=` or select the medium by label; it requires the two content markers.

## Networking / VPN

- **Tailscale remains a feasibility assessment, not a shipped feature.**
  `BR2_PACKAGE_TAILSCALE` is not selected; the `geode`/`GO386=softfloat` path is
  the only plausible PIII userspace-networking option, subject to its RAM cost.
- **Amnezia 5.0.1.5's full client is impossible** (Qt6 = x86_64-only, no i386
  build).  AmneziaWG + awg-tools are feasible in principle, but unavailable in
  this tree: no `BR2_PACKAGE_AWG`/`BR2_PACKAGE_AWG_TOOLS` symbols exist and
  neither `CONFIG_WIREGUARD` nor `CONFIG_TUN` is enabled.

## Rust

- Buildroot's default **`i686-unknown-linux-gnu`** Rust target requires Pentium 4
  / SSE2 and would raise `SIGILL` on the PIII.  `i586-unknown-linux-gnu` is a
  Tier-2 target with `std` and no SSE2 requirement, but Rust is not shipped and
  is not used for target tools.

## Current image profile

- The tree has **one defconfig**, not separate retro/practical profiles.  Its
  representative applications are CDE (`dtpad`, `dtfile`, `dtterm`), Dillo, lynx,
  MuPDF, feh, mpg123, antiword, Dropbear, btop, and fastfetch.
- NEdit, smartmontools, Ted, and NetSurf are not shipped.  Tailscale and AWG are
  not selected or packaged.

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
- **2D acceleration — capability and code path, not physical proof:** the NM2360
  has a documented BitBLT engine (solid fill, screen-to-screen blit, mono-expand
  imageblit, hardware cursor), and the in-tree `neofb` code implements the
  corresponding fill/copy/imageblit paths.  The current 6.12.104 kernel config
  enables `CONFIG_FB_NEOMAGIC` and the CFB helpers.  This does not prove operation
  on a physical 600X.  The X11/CDE path can be revisited through an EXA backend in
  `xf86-video-neomagic` or an XAA restore.  See `docs/NEOMAGIC*.md`.  Decision:
  **recover the register programming from GPL sources and build a hardware-accel
  path; do not fabricate undocumented registers.**
- **Kernel base — superseded:** the earlier 6.18 choice was replaced by
  **6.12.104 LTS** after the 440BX/Pentium III boot problem described in ADR-002.
  The current defconfig and release `bzImage` are 6.12.104.
- **Validation:** QEMU uses `modesetting` + `bochs-drm` and does not exercise a
  NeoMagic device.  Physical NeoMagic DDX and acceleration validation remain
  pending.

## Refactor (audit cleanup)

- Removed orphan `package/nedit/` (NEdit dropped — requires Boost; CDE `dtpad` +
  `nano` cover editing) and its `Config.in` source line.
- Removed empty `patches/` (all cross-compile fixes live as `sed`/hooks in the
  package `.mk`), and empty `benchmarks/`, `output/`, `research/`.

## Live media + installer

- **Kernel `root=` cannot use `LABEL=`.** The 6.12 parser (`block/early-lookup.c`,
  `early_lookup_bdev()`) accepts only `PARTUUID=`, `PARTLABEL=`, `/dev/<name>` and
  `MAJOR:MINOR`; it does not search filesystem UUIDs or labels.  A hybrid CD/USB
  image therefore cannot name one root device for both media types.
- **The live initramfs probes block devices** and requires both
  `/sbin/install-live.sh` and `/boot/bzImage`.  It mounts the ISO read-only, uses a
  RAM-backed **overlayfs** with a read-only bind-mount fallback, moves
  `/proc`, `/sys`, and `/dev`, then runs `switch_root -c /dev/console` into
  `/sbin/install-live.sh` for `live.install=1` or `/sbin/init` otherwise.
- **USB storage is built into the kernel** (`USB_UHCI_HCD`, `USB_OHCI_HCD`,
  `USB_EHCI_HCD`, `USB_STORAGE`, `BLK_DEV_SD`, `BLK_DEV_SR`, `ATA_PIIX`): the
  initramfs finds the medium before loading modules.
- **440BX kernel settings:** `CONFIG_NO_HZ_IDLE` and `CONFIG_CPU_FREQ` are off;
  boot uses `clocksource=jiffies tsc=unstable` because tickless idle and SpeedStep
  are unreliable/absent on the 440BX + Katmai.
- **Installer target safety:** it locates the live medium first, requires a real
  `/dev/sda`, and refuses `/dev/sda` or `/dev/sdaN` as that medium.  It requires
  exact `YES`, unless `live.install.auto=1` is present.
- **Partitioning and filesystem:** util-linux `sfdisk`, `blockdev`, and `partx` are
  included, with scripted BusyBox `fdisk` as a fallback.  The installer creates
  one bootable MBR partition and runs
  `mkfs.ext4 -F -L THINKPAD600X_LIV -O ^metadata_csum,^orphan_file,^64bit /dev/sda1`.
  The feature set is required because syslinux/extlinux 6.03 cannot read
  directories on filesystems carrying `metadata_csum`/`orphan_file`.
- **Boot installation:** the script copies the live tree, writes the installed
  `fstab`, `extlinux.conf`, and `syslinux.cfg`, and copies the COM32 modules.  It
  then runs `extlinux --install`, requires `ldlinux.sys` and `ldlinux.c32`, and
  writes `mbr.bin` to the first 440 bytes of sector 0.  A missing `extlinux`,
  failed installation, missing output, or missing `mbr.bin` is fatal.
- **Console ordering:** the live ISO entries and generated installed
  `extlinux.conf` use `console=ttyS0,115200 console=tty0`.  The last `console=`
  becomes `/dev/console`, so installer input/output is on VGA while serial
  remains available.
- **PID 1 behavior:** failures exec a shell on the live system rather than
  panicking; success reboots instead of exiting.  Root has an empty password.
- **Bootloader payload:** two hand-shipped overlay files, both required.
  `usr/sbin/extlinux` (i686) is hand-shipped because Buildroot's syslinux package
  builds its installers for the *host* (`~/br2-out/host/sbin/extlinux` is
  aarch64, by Buildroot's own patch 0011); the target `extlinux` is
  cross-compiled from the syslinux 6.03 tree (`docs/INSTALL.md`).
  `usr/share/syslinux/mbr.bin` is hand-shipped because Buildroot stages syslinux
  images into `$(BINARIES_DIR)/syslinux/`, **not** into `$(TARGET_DIR)` — verified
  by deleting the target copy and reinstalling the package, after which it does
  not return. Without it the image has no MBR code and the installer aborts with
  `mbr.bin not found`.
- **CDE source URL fixed:** `…/project/cdesktopenv/src` (the version-less path
  returned HTTP 404).
- **Xorg auto-detects the GPU:** `xorg.conf` pre-loads the legacy helper modules
  but does not force a video `Driver`; it also binds the classic input drivers and
  sets `DefaultDepth 16`.  Forcing `Driver "modesetting"` would bypass the real
  600X's non-KMS NeoMagic path.  Physical NeoMagic validation remains pending.

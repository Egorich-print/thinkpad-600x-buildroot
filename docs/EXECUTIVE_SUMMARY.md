# Executive summary — ThinkPad 600X Linux workstation

## What works (configured / QEMU-testable)

- **Level 1–2 (Boot + userspace)** — The supplied QEMU smoke test boots the
  release kernel and filesystem in a 64 MB `-cpu pentium3` guest. The kernel is
  **6.12.104** (`CONFIG_MPENTIUMIII`, no SMP); the configured userspace uses
  BusyBox init, devtmpfs and mdev.
- **Level 3–4 (Network + SSH)** — `scripts/qemu_test.sh` forwards host TCP 2222,
  waits for Dropbear, and can run diagnostics over SSH. `iproute2`, `iputils`
  and BusyBox `udhcpc` are selected.
- **Configured hardware support** — The supplied kernel configuration includes
  `ATA_PIIX`/`ATA_GENERIC`, the NeoMagic framebuffer, VESA fallback,
  PCMCIA/CardBus/Yenta, USB UHCI/OHCI/EHCI and storage, Ralink/MediaTek Wi-Fi,
  `THINKPAD_ACPI`, `SND_CS46XX`/`SND_INTEL8X0`, and serial-console support.
  These settings are not real-hardware validation; CS46xx sound output and
  NeoMagic behavior remain unverified beyond the existing ADR/research.
- **Level 5 (X11 stack)** — The image selects Xorg, `xf86-video-neomagic`,
  VESA/fbdev, `xinit` (`startx`) and the CDE/OpenMotif stack. It uses the
  classic `mouse` and `kbd` Xorg drivers built by
  `package/xf86-input-mouse` and `package/xf86-input-keyboard`; there is no
  udev and therefore no `xf86-input-evdev`.
- **Selected applications** — CDE desktop tools including `dtwm`, `dtterm`,
  `dtfile`, `dtpad` and `dtsession`; dillo, links and lynx; nano and mg;
  mupdf and poppler's `pdftotext`; antiword; feh; mpg123; mc; dropbear;
  fastfetch; btop; and the other utilities selected by
  `configs/thinkpad600x_defconfig`.
- **Tailscale / Amnezia** — Neither is selected in
  `configs/thinkpad600x_defconfig`; feasibility notes elsewhere do not mean
  that these applications are installed in this image.

## CDE session and remaining limits

- **CDE session (Level 6)** — CDE 2.5.3 and OpenMotif 2.3.8 are included in the
  selected package set. The configured startup path is `tty1` →
  `/usr/sbin/autostart-cde` → `/usr/bin/startx` → `/root/.xinitrc`;
  `.xinitrc` starts `dtwm` and then execs `/usr/dt/bin/Xsession`, which starts
  `ttsession` and `dtsession`. This describes the image configuration, not
  real-hardware validation.
- **Rust** — Target-side Rust is excluded because Buildroot's
  `i686-unknown-linux-gnu` baseline uses SSE2, which the Pentium III lacks.
  The alternatives and the C-based tool decision are recorded in
  `docs/adr/ADR-010-rust-infeasible.md`.
- **Benchmarks and memory** — Existing memory/benchmark documents contain
  older minimal-image measurements and predictions. They are not current CDE
  measurements; use their methodology rather than treating the old values as
  release results.

## RAM / disk targets (measured / predicted)

The configured `rootfs.ext2` is a 512 MiB ext4 filesystem image. Its filename
reflects Buildroot's image target, not a partition table or a bootable-disk
format. Current CDE memory figures are not asserted here; older RAM tables
in `docs/MEMORY.md` and `docs/BENCHMARKS.md` are historical measurements or
predictions for earlier profiles.

## Boot / deploy

- **Live bootloader** — `scripts/make-live-iso.sh` builds a hybrid CD/USB ISO
  with isolinux entries `1` Live CDE, `2` Live Safe, and `3` Install to
  internal HDD (`/dev/sda`). The supported physical flow is to write or burn
  that ISO, boot it, choose `3`, and type `YES`; the installer partitions
  `/dev/sda`, creates ext4, copies the tree, installs extlinux and the syslinux
  MBR, and reboots into the HDD.
- **`rootfs.ext2` is not a disk image** — It is a filesystem image only, with
  no partition table and no bootloader. Do not use a raw `cat` of that file as
  an installation medium.
- **Kernel command line** — The live initramfs exists because the supplied
  kernel cannot resolve `root=LABEL=`; it finds the ISO by content and uses
  overlayfs plus `switch_root`. The last `console=` becomes `/dev/console`, so
  the working installer order is `console=ttyS0,115200 console=tty0`, with
  `tty0` last.

## Security / modernity

- `glibc` (not musl) is selected for CDE, with BusyBox init, devtmpfs + mdev,
  and Dropbear; no systemd, udev, NetworkManager or avahi is selected.
- `root` has an empty password. `tty1` auto-starts CDE rather than showing a
  getty login; `ttyS0` remains a normal getty. Set a password with `passwd` if
  the disk will be exposed.
- `fastfetch` is built with heavyweight probes such as Vulkan, DRM, Wayland,
  DBus and EGL disabled. `btop` is built with GPU support disabled.

## Reproducibility

After the Buildroot 2026.05.2 checkout described in `docs/BUILD.md`, run the
one-time firmware fetch, configure and build on a Linux host:

```sh
./scripts/fetch-cs46xx-firmware.sh
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     -j"$(nproc)"
./scripts/qemu_test.sh
```

The CDE 2.5.3, OpenMotif 2.3.8 and other custom package versions are pinned in
their `package/*/*.mk` files. CDE may be supplied through `$BR2_DL_DIR`; the
repository does not require a vendored tarball.

## What is not finished (hardware validation)

- NeoMagic hardware validation beyond `docs/adr/ADR-004-display-x11.md` and the
  `docs/NEOMAGIC*.md` research remains unverified.
- CS46xx sound output remains unverified on the physical 600X. The build
  includes the `snd-cs46xx` module and the non-free firmware fetch step, but
  that does not constitute an audio-output test.

The current source defines the live/installer path and a QEMU smoke test;
neither substitutes for real-hardware validation of NeoMagic behavior or
CS46xx audio output.

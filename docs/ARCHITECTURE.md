# Architecture

```
                       +---------------------------+
                       |  Applications            |
                       |  CDE: dtfile dtterm dtpad |
                       |  dillo links lynx mutool  |
                       |  nano mg mc antiword      |
                       |  btop htop ncdu fastfetch |
                       |  mpg123 mutt irssi wget   |
                       |  tmux screen zip 7zr      |
                       |  rsync zstd sl            |
                       |  games + X utilities      |
                       |  alsa-utils dropbear      |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  CDE 2.5.3                |
                       |  dtwm + ttsession         |
                       |  dtsession (Xsession)     |
                       |  (Xsession, ksh/mksh)     |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  Xorg 21.x + neomagic     |
                       |  legacy DDX               |
                       |  libX11/…/Xt/Xm(Motif)    |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  core userspace           |
                       |  BusyBox init + mdev      |
                       |  glibc + libtirpc + lmdb  |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  Linux 6.12.104 (i686)    |
                       |  ata_piix neofb mt7601u   |
                       |  rt2xx rt2800usb          |
                       |  rtl8xxxu ath9k_htc       |
                       |  thinkpad_acpi snd-cs46xx |
                       |  no Bluetooth             |
                       +------------+--------------+
```

## Boot flow

1. BIOS → isolinux/extlinux (Syslinux) → `bzImage`; the live entries also load
   `initrd.img`.
2. The live entries have no `root=` and do not mount a pre-made root by label.
   The kernel accepts only `PARTUUID=`,
   `PARTLABEL=`, `/dev/<name>`, and `MAJOR:MINOR` (not `LABEL=`), so the tiny
   initramfs probes block devices for the media (requiring `/sbin/install-live.sh`
   and `/boot/bzImage`), mounts the matching ISO9660 read-only, and layers a
   RAM-backed `overlayfs` (with a read-only bind-mount
   fallback). It moves `/proc`, `/sys`, and `/dev`, then runs
   `switch_root -c /dev/console` into `/sbin/init` (or `/sbin/install-live.sh`
   for `live.install=1`).
3. The installed HDD uses extlinux with `root=/dev/sda1` and an ext4 root. The
   generated `rootfs.ext2` (via `BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS`) and the
   installer both omit `metadata_csum`, `orphan_file`, and `64bit`:
   extlinux/syslinux 6.03 cannot read a directory with
   `metadata_csum`/`orphan_file`, and `64bit` is unnecessary on the 40 GB PATA
   disk. The live ISO and installed extlinux use
   `console=ttyS0,115200 console=tty0`; the last `console=` becomes
   `/dev/console`.
4. BusyBox `init` reads `/etc/inittab`: mounts proc/sysfs/devpts/tmpfs, runs
   `rcS`.
5. `rcS` starts the generated services, including syslog/klog, sysctl, mdev,
   modules, `S30rpcbind`, `S40network` (DHCP on `eth0`), crond, dropbear, and
   `S95tttypes` (the target-side ToolTalk type database).
6. `tty1` runs `/usr/sbin/autostart-cde`; only `ttyS0` runs a login `getty`.
   `root` has an empty password.
7. `autostart-cde` runs `startx` with no client argument. `startx` uses
   `/root/.xinitrc`, which starts `dtwm` in the background and then execs
   `/usr/dt/bin/Xsession`; when CDE exits, the console falls back to a root shell.
8. CDE's ksh-syntax `Xsession` sets up the DT search paths/fonts and starts
   `ttsession` and `dtsession`. It does not start `dtwm`: `dtsmcmd` is not built,
   so the explicit `.xinitrc` start is required. `dtlogin` is shipped but is not
   used by this console session.

## Key dependencies

- **CDE** requires OpenMotif 2.3.8 (libXm/libMrm/libUil), libtirpc (SunRPC), LMDB,
  libjpeg, and the standard X11/Xft stack. `dtksh` is disabled to
  drop the tcl/ksh toolchain requirement.
- The i686 target uses glibc and `-march=pentium3` (MMX/SSE, no SSE2). The image
  uses BusyBox init, devtmpfs + mdev, and no systemd or udev.
- `post-build.sh` creates `/root/.xinitrc`, links `/usr/bin/ksh` to `/bin/mksh`,
  seeds the Dillo configuration, and sets `C.UTF-8` in the profile.
- **Xsession** is a ksh(93)-syntax script → run by target **mksh**. CDE's Xsession
  starts `ttsession` and `dtsession`, but not `dtwm`.
- **ToolTalk** (`ttsession`) registers with `rpcbind`; `/usr/sbin/rpcbind` is
  shipped and started. `dtlogin` and `rpc.ttdbserver` are shipped but are not used
  by this console flow; the session-manager helper `dtsmcmd` is not built.
- **Xorg 21.x** uses the legacy `xf86-video-neomagic` DDX (no KMS) and
  auto-detects the real NeoMagic or the QEMU fallback. With no udev,
  `xf86-input-evdev` is unavailable; the external `package/xf86-input-mouse` and
  `package/xf86-input-keyboard` packages build `mouse_drv.so` and `kbd_drv.so`,
  with no prebuilt input `.so` files left in the rootfs overlay.
- The full-RELRO workaround is the `xorg.conf` preload of `vgahw`, `int10`,
  `fbdevhw`, `shadow`, and `shadowfb`; `DefaultDepth 16` is set. Physical NeoMagic
  DDX validation remains pending.
- **Audio** uses `CONFIG_SND_CS46XX=m` and auto-loads it from `/etc/modules`; its
  non-free firmware is fetched by `scripts/fetch-cs46xx-firmware.sh` and is not
  committed. Real-hardware output is unverified.
- **Wi-Fi** includes MediaTek MT7601U (TL-WN727N, `148f:7601`), Ralink
  `rt2xx`/`rt2800usb`, Realtek `rtl8xxxu`/`rtl8192cu`, and `ath9k_htc`, with
  `wpa_supplicant`, `iw`, and `wireless-tools`. No Bluetooth stack or kernel
  support is configured in the current build.
- **Applications** follow the defconfig-selected set: CDE
  `dtfile`/`dtterm`/`dtpad`; dillo/links/lynx/mupdf/feh; nano/mg/mc;
  poppler-utils/antiword/mpg123;
  btop/htop/ncdu/fastfetch;
  mutt/irssi/wget/tmux/screen; zip/unzip/7zr/rsync/zstd;
  gnuchess/ascii-invaders/cmatrix/nyancat/aquarium/chocolate-doom+doom-wad; sl;
  X utilities; alsa-utils/dropbear; and the iproute2, iputils, pciutils, usbutils,
  coreutils, wpa_supplicant, iw, and wireless-tools utilities.

## RAM economics

- Kernel image: ~3.9 MB; resident-kernel and base-userspace figures are historical
  estimates.
- Xorg + neomagic: ~10-12 MB predicted; the CDE/dtwm layer: ~20-25 MB predicted.
- These are estimates/predictions, not verified physical-600X measurements; see
  `docs/MEMORY.md` / `docs/BENCHMARKS.md`.
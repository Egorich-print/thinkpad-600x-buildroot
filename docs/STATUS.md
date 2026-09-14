# Status / resume state

Last updated: live-media + on-device installer work (validated in QEMU).

## Status: working — live CD/USB boots, installs to HDD, installed HDD boots

Validated end-to-end in QEMU (`-M pc -cpu pentium3`):

1. **Live boot from CD** (El Torito + initramfs) → overlayfs writable root → login.
2. **Live boot from USB** (USB stick holding the ISO, after an internal IDE disk) →
   media found on `/dev/sdb` → login.
3. **Install to internal HDD** (`live.install=1`) → MBR + ext4 + extlinux.
4. **Boot the installed HDD** → `SYSLINUX 6.03` → ext4 root → login.

## Kernel: Linux 6.12.104 LTS (i686, `-march=pentium3`, glibc 2.41)

- `CONFIG_MPENTIUMIII`, SMP off, `CC_OPTIMIZE_FOR_SIZE` (`-Os`).
- **440BX stability:** `CONFIG_NO_HZ_IDLE` **off** (tickless idle hangs the 440BX
  APIC/PIT), `CONFIG_CPU_FREQ` off (no SpeedStep on Katmai), `HZ_100`.
- **Live USB boot needs the storage path built-in:** `USB`, `USB_UHCI_HCD`,
  `USB_EHCI_HCD`, `USB_STORAGE`, `BLK_DEV_SD`, `BLK_DEV_SR`, `ATA_PIIX` are all `=y`
  so the initramfs can find the live medium before any module can be loaded.
- `CONFIG_ACPI_VIDEO` off (conflicts with `thinkpad_acpi` backlight), `USB_XHCI` off
  (440BX is USB 1.1 only), `BLK_DEV_RAM_SIZE=8192` (was 32 MB on a 64 MB box).
- NeoMagic `FB_NEOMAGIC=y` (console) + `FB_VESA`; DRM (`bochs`/`simpledrm`) as
  modules for QEMU only.

## Live media: why an initramfs (important)

The kernel's `root=` parser (`block/early-lookup.c`) understands only
`PARTUUID=`, `PARTLABEL=`, `/dev/<name>` and `MAJOR:MINOR` — **not `LABEL=`**
(and not filesystem UUIDs). A single hybrid CD/USB image therefore cannot name
its own root: on a CD the ISO is `/dev/sr0`, on a USB stick it is `/dev/sdX`
(usually `/dev/sdb`, after the internal PATA disk).

Solution (`board/thinkpad600x/initramfs/init`, ~1.5 MB, loaded via isolinux
`INITRD`): probe the block devices for the live media (marker
`/sbin/install-live.sh` + `/boot/bzImage`), mount it read-only, layer a
RAM-backed **overlayfs** for a writable live root, move `/proc /sys /dev` and
`switch_root` into it. `live.install=1` runs the installer instead of `/sbin/init`.

Earlier attempts that do **not** work: `root=LABEL=THINKPAD600X_LIV`
(kernel rejects it: "Disabling rootwait; root= is invalid" → panic) and a plain
`root=/dev/sr0` (fails on USB).

## On-device installer (`/sbin/install-live.sh`, label 3)

- `sfdisk` creates an MBR + one bootable Linux partition on `/dev/sda`
  (util-linux "basic set" added for `sfdisk`/`blockdev`/`partx`).
- `mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit` — **syslinux/extlinux 6.03
  cannot read directories on a filesystem with `metadata_csum`/`orphan_file`**
  (symptom: "No configuration file found").
- Copies the live tree, writes `extlinux.conf` + `syslinux.cfg`, copies the
  COM32 modules, runs `extlinux --install /boot`, then writes `mbr.bin` to
  sector 0 (first 440 bytes only).
- `extlinux` (i686) + `mbr.bin` are shipped in the rootfs overlay
  (`usr/sbin/extlinux`, `usr/share/syslinux/mbr.bin`) because Buildroot's
  syslinux package builds its installers for the *host*. Regeneration is done by
  `BR2_TARGET_SYSLINUX` + the cross-compile step documented in `docs/INSTALL.md`.
- Unattended mode for testing: `live.install.auto=1` skips the `YES` prompt.

## X11 / NeoMagic

- `xorg.conf` no longer forces a driver: Xorg auto-detects, giving
  `neomagic` on the real 600X and `modesetting`/`fbdev`/`vesa` in QEMU.
- The legacy-DDX helper modules (`vgahw/int10/fbdevhw/shadow/shadowfb`) are still
  pre-loaded to work around full-RELRO `-z now` breaking their lazy `dlopen`
  (see `docs/X11.md`). Not a neomagic bug.

## Applications / stack

- OpenMotif 2.3.8 + CDE 2.5.3 → `/usr/dt` (`dtsession`/`dtwm`/`dtterm`/`dtfile`).
- Dillo, lynx, MuPDF, feh, mpg123, mc, nano, antiword, dropbear, btop, fastfetch.
- Wi-Fi: `mt7601u` (TL-WN727N 148f:7601) + `rt2800usb`; wpa_supplicant/iw.
- No systemd/udev; BusyBox init + devtmpfs + mdev; console VGA + serial getty.

## Release artifacts (`release/`)

- `bzImage` ~3.8 MB, `rootfs.ext2` 512 MB, `rootfs.tar` ~212 MB.
- Live hybrid ISO: `/tmp/thinkpad600x-live.iso` (~210 MB) built by
  `scripts/make-live-iso.sh`.
- `SHA256SUMS.txt` present (binaries are git-ignored; checksums are tracked).

# Status / resume state

Last updated: live-media + on-device installer work (local QEMU report; no retained logs).

## Status: reported working — live CD/USB boots, installs to HDD, installed HDD boots

The operator reported an end-to-end QEMU run for the following flow
(`-M pc -cpu pentium3`); it is not reproducible from the repository:

1. **Live boot from CD** (El Torito + initramfs) → overlayfs writable root → login.
2. **Live boot from USB** (USB stick holding the ISO, after an internal IDE disk) →
   media found on `/dev/sdb` → login.
3. **Install to internal HDD** (`live.install=1`) → MBR + ext4 + extlinux.
4. **Boot the installed HDD** → `SYSLINUX 6.03` → ext4 root → login.

No boot log is tracked in the repository (`release/*.log` is git-ignored; only
`release/SHA256SUMS.txt` is committed). A local capture of a direct
kernel+rootfs boot under QEMU (`root=/dev/sda`, no initramfs) reached the serial
login prompt on `ttyS0`, but it comes from a 6.18.7 image, so the live-media
(CD/USB) flows above have no retained evidence either.

## Kernel: Linux 6.12.104 LTS (i686, `-march=pentium3`, glibc)

- `CONFIG_MPENTIUMIII`, SMP off, `CONFIG_CC_OPTIMIZE_FOR_SIZE=y` (`-Os`).
- **440BX stability:** `CONFIG_NO_HZ_IDLE` **off** (tickless idle hangs the 440BX
  APIC/PIT), `CONFIG_CPU_FREQ` off (no SpeedStep on Katmai), `CONFIG_HZ_100=y`.
- **Live USB boot needs the storage path built-in:** `USB`, `USB_UHCI_HCD`,
  `USB_EHCI_HCD`, `USB_STORAGE`, `BLK_DEV_SD`, `BLK_DEV_SR`, `ATA_PIIX` are all `=y`
  so the initramfs can find the live medium before any module can be loaded.
- `CONFIG_ACPI_VIDEO` off (conflicts with `thinkpad_acpi` backlight),
  `CONFIG_USB_XHCI_HCD` off (440BX is USB 1.1 only),
  `CONFIG_BLK_DEV_RAM_SIZE=8192` (was 32 MB on a 64 MB box).
- NeoMagic `CONFIG_FB_NEOMAGIC=y` (console) + `CONFIG_FB_VESA=y`; DRM
  (`bochs`/`simpledrm`) as modules for QEMU only.

## Live media: why an initramfs (important)

The kernel's `root=` parser (`block/early-lookup.c`) understands only
`PARTUUID=`, `PARTLABEL=`, `/dev/<name>` and `MAJOR:MINOR` — **not `LABEL=`**
(and not filesystem UUIDs). A single hybrid CD/USB image therefore cannot name
its own root: on a CD the ISO is `/dev/sr0`, on a USB stick it is `/dev/sdX`
(usually `/dev/sdb`, after the internal PATA disk).

Solution (`board/thinkpad600x/initramfs/init`, loaded via isolinux
  `INITRD`): probe the block devices for the live media (marker
`/sbin/install-live.sh` + `/boot/bzImage`), mount it read-only, layer a
RAM-backed **overlayfs** for a writable live root, move `/proc /sys /dev` and
`switch_root` into it. `live.install=1` runs the installer instead of `/sbin/init`.

Earlier attempts that do **not** work: `root=LABEL=THINKPAD600X_LIV`
(kernel rejects it: "Disabling rootwait; root= is invalid" → panic) and a plain
`root=/dev/sr0` (fails on USB).

The initramfs ships busybox plus the libraries its ELF `NEEDED` entries name, and
`scripts/make-live-iso.sh` resolves that list from the binary (CDE selects
`linux-pam`, which makes Buildroot enable BusyBox PAM, so `libpam`,
`libpam_misc` and `libtirpc` from `/usr/lib` are needed too). Hand-writing the
library list produced a media that panicked with `Attempted to kill init!
exitcode=0x00007f00`; the script now fails the build instead. `/init` also
reconnects stdio to `/dev/console` after mounting devtmpfs, because PID 1 starts
before `/dev` exists and otherwise loses every message.

Verified under QEMU (`-cpu pentium3`, 64 MB, ISO as CD): `media found on
/dev/sr0` → `overlayfs ready` → `switch_root` → full BusyBox userspace → login
prompt.

## On-device installer (`/sbin/install-live.sh`, label 3)

- `sfdisk` creates an MBR + one bootable Linux partition on `/dev/sda`
  (util-linux "basic set" added for `sfdisk`/`blockdev`/`partx`).
- `mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit` — **syslinux/extlinux 6.03
  cannot read directories on a filesystem with `metadata_csum`/`orphan_file`**
  (symptom: "No configuration file found").
- Copies the live tree, writes `extlinux.conf` + `syslinux.cfg`, copies the
  COM32 modules, runs `extlinux --install /mnt/target/boot`, then writes `mbr.bin` to
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
  (see `docs/X11.md`; `docs/adr/ADR-004-display-x11.md`). Not a neomagic bug.
- The NeoMagic result is still **pending physical 600X validation** — no
  emulator models the chip; no hardware result is recorded in the repository
  (`docs/NEOMAGIC_PHYSICAL_TEST.md` and `docs/NEOMAGIC_BENCHMARKS.md` contain
  plans but no recorded measurements).

## Applications / stack

- OpenMotif 2.3.8 + CDE 2.5.3 → `/usr/dt` (`dtsession`/`dtwm`/`dtterm`/`dtfile`/`dtpad`).
- Editors: nano, mg, and CDE's `dtpad`; viewers: dillo, links, lynx, mupdf,
  feh; poppler-utils (e.g. `pdftotext`) and antiword for documents; plus mpg123,
  mc, dropbear, btop, fastfetch and the console utilities
  (`configs/thinkpad600x_defconfig`).
- VGA console (`tty1`): `/usr/sbin/autostart-cde` → `startx` →
  `/root/.xinitrc` → `dtwm` + CDE `Xsession`; a root shell takes over when
  CDE exits. The only login getty is on `ttyS0` (empty root password: Enter).
- Audio: Crystal CS46xx (600X) — driver `CONFIG_SND_CS46XX=m` (auto-loaded from
  `/etc/modules`) and DSP firmware under `/lib/firmware/cs46xx/`
  (`ba1 cwc4630 …`), fetched at build time by
  `scripts/fetch-cs46xx-firmware.sh` (non-free, not committed). Output is
  **not verified on real hardware** — no such evidence is in the repository.
- Network: `BR2_SYSTEM_DHCP="eth0"` runs `udhcpc` at boot; no DHCP lease is
  evidenced in the repository. A local, pre-6.12 QEMU capture shows
  `e1000 … eth0` detected but `udhcpc: no lease, forking to background`.
- Wi-Fi: `mt7601u` (TL-WN727N 148f:7601) + `rt2800usb`; wpa_supplicant/iw.
- No systemd/udev; BusyBox init + devtmpfs + mdev.

## Release artifacts (`release/`)

- `bzImage` ≈3.9 MB, `rootfs.ext2` = 512 MiB image, `rootfs.tar` ≈270 MiB
  (~283 MB) (approximate; the release artifacts are being regenerated — measure
  with `ls -l release/` and check `release/SHA256SUMS.txt`).
- Live hybrid ISO: `/tmp/thinkpad600x-live.iso` (built on demand by
  `scripts/make-live-iso.sh`; not shipped — size follows `rootfs.tar`, ≈270 MiB
  plus bootloader overhead).
- `SHA256SUMS.txt` present (binaries are git-ignored; checksums are tracked).

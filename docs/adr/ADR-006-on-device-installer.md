# ADR-006 — On-device HDD installer

- **Status:** accepted
- **Date:** 2026-09-14

## Context

Installing to the internal 40 GB PATA disk must work from the live medium alone
(no host-side tools, no second machine).  Two boot constraints apply:

1. **The last `console=` becomes `/dev/console`.**  An earlier
   `console=tty0 console=ttyS0,115200` ordering therefore sent the installer
   prompt and `YES` input to serial rather than VGA.
2. syslinux/extlinux **6.03 cannot read directories on an ext4 filesystem with
   `metadata_csum`/`orphan_file`** (modern `mke2fs` enables both): the symptom is
   *"No configuration file found"*.

## Decision

`/sbin/install-live.sh` (label 3 in the isolinux menu, entered through
`live.install=1`) runs as PID 1 and:

- first locates the read-only live medium by the same two content markers used by
  the initramfs: `/sbin/install-live.sh` and `/boot/bzImage`;
- requires a real block `/dev/sda` and refuses to install when that medium is
  `/dev/sda` or a `/dev/sdaN` partition;
- requires the exact confirmation `YES`, unless `live.install.auto=1` is present;
- unmounts existing `/dev/sdaN` partitions, uses `sfdisk` to create an MBR with
  one bootable Linux partition, and falls back to scripted BusyBox `fdisk` when
  `sfdisk` is unavailable; it then rereads the partition table and waits for
  `/dev/sda1`;
- runs
  `mkfs.ext4 -F -L THINKPAD600X_LIV -O ^metadata_csum,^orphan_file,^64bit /dev/sda1`,
  copies the live tree, and writes the installed `fstab`, `extlinux.conf`, and
  `syslinux.cfg`;
- copies the COM32 modules, runs `extlinux --install /mnt/target/boot`, and
  requires both `ldlinux.sys` and `ldlinux.c32`; a missing `extlinux` command,
  failed install, or missing output is fatal;
- writes `mbr.bin` to only the first 440 bytes of sector 0, preserving the
  partition table; a missing MBR file is fatal;
- syncs, unmounts, and runs `reboot -f`.

The live ISO entries and generated installed `extlinux.conf` use
`console=ttyS0,115200 console=tty0`: the last entry makes VGA `/dev/console`, so
the prompt and input are on VGA while serial remains available.  Root has an
empty password.

Two overlay files are hand-shipped for the bootloader.  `extlinux` (i686) ships
because Buildroot's syslinux package builds its installers for the *host*; it is
cross-compiled from the syslinux 6.03 tree with the target toolchain from
`~/br2-out/host/bin` (`docs/INSTALL.md` carries the exact recipe).
`usr/share/syslinux/mbr.bin` ships because Buildroot stages syslinux images into
`$(BINARIES_DIR)/syslinux/`, not into `$(TARGET_DIR)` — removing the target copy
and reinstalling the package does not bring it back — so the overlay copy is the
only source of the MBR code in the image.  The installer reads the single
in-image path `/usr/share/syslinux/mbr.bin` and treats a missing file as fatal,
so `scripts/check.sh` asserts the overlay copy exists.

## Consequences

The installer is self-contained and treats every critical failure as fatal to the
install flow.  Because it is PID 1, `die()` drops to a shell on the live system
instead of allowing the kernel to panic; a successful install reboots rather than
exits.

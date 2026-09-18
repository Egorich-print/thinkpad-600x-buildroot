# ADR-006 — On-device HDD installer

- **Status:** accepted
- **Date:** 2026-09-14

## Context

Installing to the internal 40 GB PATA disk must work from the live medium alone
(no host-side tools, no second machine).  Two problems surfaced on real hardware:

1. The installer appeared to hang: the kernel cmdline was
   `console=tty0 console=ttyS0,115200`, and **the last `console=` becomes
   `/dev/console`** — so the installer wrote its prompt and read `YES` from the
   serial port, not the VGA console.
2. syslinux/extlinux **6.03 cannot read directories on an ext4 filesystem with
   `metadata_csum`/`orphan_file`** (modern `mke2fs` enables both): the symptom is
   *"No configuration file found"*.

## Decision

`/sbin/install-live.sh` (label 3 in the isolinux menu):

- print/read on the VGA console (cmdline ends with `console=tty0`);
- `sfdisk` an MBR with one bootable Linux partition on `/dev/sda`
  (util-linux "basic set" is included for `sfdisk`/`blockdev`/`partx`);
- `mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit`;
- copy the live tree, write `extlinux.conf` + `syslinux.cfg`, copy the COM32
  modules, `extlinux --install /boot`, then write `mbr.bin` to sector 0;
- `reboot -f` (the script is PID 1; exiting would panic).

`extlinux` (i686) and `mbr.bin` ship in the rootfs overlay, because Buildroot's
syslinux package builds its installers for the *host*; the i686 `extlinux` is
cross-compiled from the syslinux tree with `CC_FOR_BUILD` set to the target
toolchain.

## Consequences

A clean end-to-end flow: live boot → install → reboot → the HDD boots via
syslinux 6.03 into the installed ext4 root.

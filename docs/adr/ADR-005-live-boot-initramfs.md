# ADR-005 — Live media boot via initramfs + overlayfs

- **Status:** accepted
- **Date:** 2026-09-14

## Context

The release medium is a single hybrid CD/USB image that must boot both from a
CD (`/dev/sr0`) and from a USB stick (`/dev/sdX`, usually `/dev/sdb` after the
internal PATA disk).  The kernel's `root=` parser (`block/early-lookup.c`) accepts
only `PARTUUID=`, `PARTLABEL=`, `/dev/<name>` and `MAJOR:MINOR` — **not
`LABEL=`** (and not filesystem UUIDs).  A `root=LABEL=…` entry makes the kernel
print *"Disabling rootwait; root= is invalid"* and panic on a PIII-class machine;
`root=/dev/sr0` fails on USB.

## Decision

Boot a small **initramfs** (`board/thinkpad600x/initramfs/init`, ~1.5 MB, loaded
via the isolinux `INITRD` directive) that:

1. probes block devices for the live media (markers `/sbin/install-live.sh` +
   `/boot/bzImage`);
2. mounts it read-only and layers a **RAM-backed overlayfs** for a writable live
   root;
3. moves `/proc /sys /dev` and `switch_root`s into it.

Kernel support is built in (`USB`, `USB_UHCI_HCD`, `USB_EHCI_HCD`, `USB_STORAGE`,
`BLK_DEV_SD`, `BLK_DEV_SR`, `ATA_PIIX`) so the medium is found before any module
can be loaded.

## Consequences

One image boots from CD and USB.  The live root is writable (RAM).  The same
mechanism carries the installer flag (`live.install=1`).

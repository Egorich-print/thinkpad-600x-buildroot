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

Boot a small **initramfs** (`board/thinkpad600x/initramfs/init`, loaded via the
isolinux `INITRD` directive) that:

1. mounts `/proc`, `/sys`, and `/dev`, then makes 15 probe passes over
   `/dev/sr0`–`sr2`, `/dev/sda`–`sdf`, and their first partitions, mounting each
   candidate as read-only ISO9660 until **both** `/sbin/install-live.sh` and
   `/boot/bzImage` are present;
2. mounts a RAM-backed tmpfs for the overlay upper/work directories and creates a
   **RAM-backed overlayfs** rooted at the live medium, falling back to a read-only
   bind mount if overlayfs is unavailable;
3. reads `live.install=1`, moves `/proc`, `/sys`, and `/dev` into the new root, and
   runs `switch_root -c /dev/console /newroot` into either
   `/sbin/install-live.sh` or `/sbin/init`.

Kernel support is built in (`USB`, `USB_UHCI_HCD`, `USB_OHCI_HCD`,
`USB_EHCI_HCD`, `USB_STORAGE`, `BLK_DEV_SD`, `BLK_DEV_SR`, `ATA_PIIX`) so the
medium is found before any module can be loaded.

## Consequences

One image boots from CD and USB.  The live root is writable in RAM when
overlayfs is available and read-only under the bind-mount fallback.
`live.install=1` selects the installer instead of the normal BusyBox init.

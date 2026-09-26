#!/bin/bash
# make-live-iso.sh — build a bootable hybrid live CD/USB ISO for the ThinkPad 600X
#
# Requires: xorriso, cpio, gzip, and release/{rootfs.tar,bzImage}.
# isolinux.bin/isohdpfx.bin are taken from the host or, on macOS, from the
# lima build VM (limactl shell br2).
#
# The image boots a tiny initramfs (see board/thinkpad600x/initramfs/init)
# which locates the live media by contents and mounts a writable overlayfs,
# so the *same* ISO boots from a CD (/dev/sr0) and from a USB stick (/dev/sdX).
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/release"
INITRAMFS_SRC="$PROJECT_DIR/board/thinkpad600x/initramfs"
ISO_OUT="${ISO_OUT:-/tmp/thinkpad600x-live.iso}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/thinkpad600x-live.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
STAGING="$WORK/staging"
INITRD_STAGE="$WORK/initrd"

echo "=== Building ThinkPad 600X live ISO (hybrid CD/USB) ==="
mkdir -p "$STAGING/boot/isolinux"

# 1. Unpack the target rootfs — this becomes the read-only live root.
echo "Unpacking rootfs.tar -> $STAGING ..."
tar -xf "$RELEASE_DIR/rootfs.tar" -C "$STAGING"

# 2. Kernel
cp "$RELEASE_DIR/bzImage" "$STAGING/boot/bzImage"
echo "bzImage copied"

# 3. Build the live-boot initramfs (busybox + the shared libraries it needs).
#    The library list is derived from the binary itself: Buildroot switches
#    BusyBox PAM support on whenever linux-pam is selected (CDE pulls it in), so
#    busybox additionally needs libpam, libpam_misc and libtirpc out of /usr/lib.
#    A hand-written list silently produced an initramfs whose /init could not
#    even start, which the kernel reports only as "Attempted to kill init!".
echo "Building initramfs -> /boot/initrd.img ..."
mkdir -p "$INITRD_STAGE"/{bin,lib,usr/lib,mnt,proc,sys,dev}
tar -xf "$RELEASE_DIR/rootfs.tar" -C "$INITRD_STAGE" ./bin/busybox
ln -sf busybox "$INITRD_STAGE/bin/sh"
cp "$INITRAMFS_SRC/init" "$INITRD_STAGE/init"
chmod +x "$INITRD_STAGE/init"

needed_libs() {
    if command -v objdump >/dev/null 2>&1; then
        objdump -p "$1" 2>/dev/null | awk '/NEEDED/ {print $2}'
    elif command -v readelf >/dev/null 2>&1; then
        readelf -d "$1" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'
    else
        echo "ERROR: need objdump or readelf to resolve the initramfs libraries" >&2
        return 1
    fi
}

# The ELF interpreter is not a NEEDED entry, so add it explicitly.
for lib in ld-linux.so.2 $(needed_libs "$INITRD_STAGE/bin/busybox"); do
    esc="${lib//./\\.}"
    paths="$(tar -tf "$RELEASE_DIR/rootfs.tar" | grep -E "^\./(usr/)?lib/${esc}(\.[0-9.]+)*$")"
    if [ -z "$paths" ]; then
        echo "ERROR: busybox needs '$lib', which is not in release/rootfs.tar" >&2
        exit 1
    fi
    # shellcheck disable=SC2086
    tar -xf "$RELEASE_DIR/rootfs.tar" -C "$INITRD_STAGE" $paths
    echo "  initrd: $lib"
done

( cd "$INITRD_STAGE" && find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 ) \
    > "$STAGING/boot/initrd.img"
ls -lh "$STAGING/boot/initrd.img"

# 4. isolinux bootloader (host, or from the lima VM on macOS).
ISOLINUX_BIN="/usr/lib/ISOLINUX/isolinux.bin"
ISOHDPFX="/usr/lib/ISOLINUX/isohdpfx.bin"
LDLINUX="/usr/lib/syslinux/modules/bios/ldlinux.c32"

if [[ ! -f "$ISOLINUX_BIN" ]]; then
  if limactl shell br2 -- test -f /usr/lib/ISOLINUX/isolinux.bin 2>/dev/null; then
    echo "Copying isolinux from the br2 VM..."
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isolinux.bin    > "$WORK/isolinux.bin"
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isohdpfx.bin    > "$WORK/isohdpfx.bin"
    limactl shell br2 -- cat /usr/lib/syslinux/modules/bios/ldlinux.c32 > "$WORK/ldlinux.c32"
    ISOLINUX_BIN="$WORK/isolinux.bin"
    ISOHDPFX="$WORK/isohdpfx.bin"
    LDLINUX="$WORK/ldlinux.c32"
  elif [[ -f "/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin" ]]; then
    ISOLINUX_BIN="/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin"
    echo "Using isolinux from VMware Fusion"
  fi
fi

# Boot-critical assets.  A build that silently misses these still "succeeds",
# but yields a CD-only image, or a HDD install whose extlinux cannot read its
# own config.  Fail the build instead.
for f in "$ISOLINUX_BIN" "$LDLINUX"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing boot-critical file: $f" >&2
    exit 1
  fi
done
if [[ -z "$ISOHDPFX" ]] || [[ ! -f "$ISOHDPFX" ]]; then
  echo "ERROR: isohdpfx.bin not found - the ISO would not boot from a USB disk" >&2
  exit 1
fi
cp "$ISOLINUX_BIN" "$STAGING/boot/isolinux/"
cp "$LDLINUX"      "$STAGING/boot/isolinux/"

# 5. isolinux config. No root= is needed: the initramfs finds the media.
#    Plain digit menu (no menu.c32 — the 1999 BIOS hangs on the UI module).
cat > "$STAGING/boot/isolinux/isolinux.cfg" <<'EOF'
DEFAULT 1
PROMPT 1
TIMEOUT 0
DISPLAY boot.msg
LABEL 1
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND console=ttyS0,115200 console=tty0 acpi=off clocksource=jiffies tsc=unstable
LABEL 2
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND console=ttyS0,115200 console=tty0 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable
LABEL 3
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND console=ttyS0,115200 console=tty0 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable live.install=1
EOF
cat > "$STAGING/boot/isolinux/boot.msg" <<'EOF'
ThinkPad 600X Live (6.12.104)
1 - Live CDE
2 - Live Safe (noapic/nolapic)
3 - Install to internal HDD (/dev/sda)

Press 1, 2 or 3 then Enter
EOF

# 6. The HDD installer ships inside the live root as /sbin/install-live.sh.
mkdir -p "$STAGING/sbin"
cat > "$STAGING/sbin/install-live.sh" <<'EOS'
#!/bin/sh
# ThinkPad 600X live installer: copy the live system onto the internal PATA disk.
#
# switch_root execs this, so it runs as PID 1: exiting on failure would panic the
# kernel.  There is deliberately no "set -e" (its behaviour around the conditionals
# below is easy to misread), so every critical step is checked explicitly and a
# failure drops back to a shell on the live system.

die() { echo; echo "ERROR: $*"; echo "Dropping to a shell on the live system."; exec /bin/sh; }

cmdline_has() {
    for t in $(cat /proc/cmdline 2>/dev/null); do
        [ "$t" = "$1" ] && return 0
    done
    return 1
}

echo "=== ThinkPad 600X Live Installer ==="
echo
echo "Available disks:"
cat /proc/partitions
echo

# Find the live media before touching anything: it must never be the target.
CD=""
for dev in /dev/sr0 /dev/sr1 /dev/sr2 \
           /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf \
           /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1; do
  [ -b "$dev" ] || continue
  mkdir -p /mnt/src
  if mount -t iso9660 -o ro "$dev" /mnt/src 2>/dev/null; then
    if [ -e /mnt/src/sbin/install-live.sh ] && [ -e /mnt/src/boot/bzImage ]; then
      CD="$dev"
      break
    fi
    umount /mnt/src 2>/dev/null || true
  fi
done
[ -n "$CD" ] || die "live media not found"
echo "Live media: $CD"

[ -b /dev/sda ] || die "/dev/sda is not present (USB-booted without the internal disk?)"
case "$CD" in
    /dev/sda|/dev/sda[0-9]*) die "refusing to install: the live media is on $CD" ;;
esac

echo "Target: /dev/sda (the internal PATA disk). ALL DATA ON IT WILL BE ERASED."
if cmdline_has live.install.auto=1; then
  echo "Unattended mode (live.install.auto=1): proceeding."
else
  printf "Type YES to continue: "
  read confirm || die "aborted"
  [ "$confirm" = "YES" ] || die "aborted by user"
fi

umount /dev/sda[0-9]* 2>/dev/null || true

echo "Partitioning /dev/sda (MBR + one bootable partition)..."
if command -v sfdisk >/dev/null 2>&1; then
  printf 'label: dos\nstart=2048, type=83, bootable\n' | sfdisk /dev/sda
else
  # busybox fdisk fallback (less reliable; prefer util-linux sfdisk)
  printf 'o\nn\np\n1\n\n\nw\n' | fdisk /dev/sda
fi
# Make the kernel re-read the partition table.
blockdev --rereadpt /dev/sda 2>/dev/null || partx -a /dev/sda 2>/dev/null || true
i=0
while [ ! -b /dev/sda1 ] && [ "$i" -lt 15 ]; do sleep 1; i=$((i+1)); done
TARGET_PART=/dev/sda1
[ -b "$TARGET_PART" ] || die "/dev/sda1 did not appear after partitioning"

echo "Creating ext4 on $TARGET_PART ..."
# syslinux/extlinux 6.03 cannot read directories on a filesystem with
# metadata_csum/orphan_file (and 64bit is pointless on a 40 GB disk), so create
# the root filesystem without those features.
mkfs.ext4 -F -L THINKPAD600X_LIV -O ^metadata_csum,^orphan_file,^64bit "$TARGET_PART" \
  || die "mkfs.ext4 failed"

mkdir -p /mnt/target
mount "$TARGET_PART" /mnt/target || die "cannot mount $TARGET_PART"

echo "Copying live files onto $TARGET_PART (~200 MB)..."
cp -a /mnt/src/. /mnt/target/ || die "copying the live tree failed"

# Bootloader config for the installed system: boot from the ext4 root.
cat > /mnt/target/boot/extlinux.conf <<'CFG'
DEFAULT linux
PROMPT 0
TIMEOUT 30
LABEL linux
  KERNEL /boot/bzImage
  APPEND root=/dev/sda1 rootfstype=ext4 rw rootwait console=ttyS0,115200 console=tty0 acpi=off clocksource=jiffies tsc=unstable
CFG
cp /mnt/target/boot/extlinux.conf /mnt/target/boot/syslinux.cfg

# Point the installed system's fstab at the real root device.
cat > /mnt/target/etc/fstab <<'CFG'
/dev/sda1       /         ext4    rw,noatime              0 1
proc            /proc     proc    defaults                0 0
sysfs           /sys      sysfs   defaults                0 0
devpts          /dev/pts  devpts  defaults,gid=5,mode=620 0 0
tmpfs           /dev/shm  tmpfs   mode=1777,nosuid,nodev  0 0
tmpfs           /tmp      tmpfs   defaults,size=32M       0 0
tmpfs           /run      tmpfs   defaults,size=8M,mode=0755 0 0
CFG

# Copy the syslinux COM32 modules next to the kernel: extlinux needs ldlinux.c32
# to interpret extlinux.conf, and the live ISO already carries them.
for c32 in /mnt/src/boot/isolinux/*.c32; do
  [ -f "$c32" ] && cp "$c32" /mnt/target/boot/
done

# Install the extlinux bootloader into the partition's VBR (creates ldlinux.sys).
# Missing or failing here means an unbootable disk, so it is fatal, not a warning.
command -v extlinux >/dev/null 2>&1 || die "extlinux is missing from the image"
echo "Installing extlinux..."
extlinux --install /mnt/target/boot || die "extlinux --install failed"
[ -f /mnt/target/boot/ldlinux.sys ] || die "ldlinux.sys was not created"
[ -f /mnt/target/boot/ldlinux.c32 ] || die "ldlinux.c32 is missing from /boot"

# Write the syslinux MBR code to sector 0 (first 440 bytes only, so the
# partition table stays intact).  Without it the disk does not boot at all.
# /usr/share/syslinux/mbr.bin comes from Buildroot's syslinux target
# (BR2_TARGET_SYSLINUX_MBR=y); the overlay does not carry a copy.
MBR_OK=0
if [ -f /usr/share/syslinux/mbr.bin ]; then
    dd if=/usr/share/syslinux/mbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>/dev/null && MBR_OK=1
fi
[ "$MBR_OK" = 1 ] || die "mbr.bin not found - the installed disk would not boot"

sync
umount /mnt/target || die "cannot unmount $TARGET_PART"
umount /mnt/src 2>/dev/null || true
echo
echo "Installation complete."
echo "Remove the CD/USB and the system will reboot into the installed HDD."
echo "Login: root (no password)"
echo
sync
# This script runs as PID 1; exiting would panic. Reboot instead.
reboot -f 2>/dev/null || exec sh
EOS
chmod +x "$STAGING/sbin/install-live.sh"

# 7. Build the hybrid ISO (El Torito for CD + isohybrid MBR for USB/Plop).
echo "Building hybrid ISO ..."
ISOHDPFX_OPT=""
[ -n "$ISOHDPFX" ] && [ -f "$ISOHDPFX" ] && ISOHDPFX_OPT="-isohybrid-mbr $ISOHDPFX"

if command -v xorrisofs >/dev/null 2>&1; then
  XORRISO=xorrisofs
elif command -v mkisofs >/dev/null 2>&1; then
  XORRISO=mkisofs
else
  XORRISO="/opt/homebrew/bin/xorrisofs"
fi

$XORRISO -o "$ISO_OUT" \
  -R -J -V "THINKPAD600X_LIV" \
  -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  $ISOHDPFX_OPT \
  "$STAGING" 2>&1 | tail -15

echo
ls -lh "$ISO_OUT"
if command -v sha256sum >/dev/null 2>&1; then
  ( cd "$(dirname "$ISO_OUT")" && sha256sum "$(basename "$ISO_OUT")" ) > "$ISO_OUT.sha256"
else
  shasum -a 256 "$ISO_OUT" > "$ISO_OUT.sha256"
fi
echo "Done: $ISO_OUT  (checksum: $ISO_OUT.sha256)"
echo "USB:  diskutil unmountDisk /dev/diskN && sudo dd if=$ISO_OUT of=/dev/rdiskN bs=1m"
echo "CD:   hdiutil burn \"$ISO_OUT\" -speed 4"

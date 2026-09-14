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
STAGING="/tmp/thinkpad-live-staging"
INITRD_STAGE="/tmp/thinkpad-initrd"
ISO_OUT="/tmp/thinkpad600x-live.iso"

echo "=== Building ThinkPad 600X live ISO (hybrid CD/USB) ==="
rm -rf "$STAGING" "$INITRD_STAGE" "$ISO_OUT"
mkdir -p "$STAGING/boot/isolinux"

# 1. Unpack the target rootfs — this becomes the read-only live root.
echo "Unpacking rootfs.tar -> $STAGING ..."
tar -xf "$RELEASE_DIR/rootfs.tar" -C "$STAGING"

# 2. Kernel
cp "$RELEASE_DIR/bzImage" "$STAGING/boot/bzImage"
echo "bzImage copied"

# 3. Build the live-boot initramfs (busybox + shared libs + /init).
echo "Building initramfs -> /boot/initrd.img ..."
mkdir -p "$INITRD_STAGE"/{bin,lib,mnt,proc,sys,dev}
tar -xf "$RELEASE_DIR/rootfs.tar" -C "$INITRD_STAGE" \
    ./bin/busybox ./lib/ld-linux.so.2 ./lib/libc.so.6 ./lib/libresolv.so.2
ln -sf busybox "$INITRD_STAGE/bin/sh"
cp "$INITRAMFS_SRC/init" "$INITRD_STAGE/init"
chmod +x "$INITRD_STAGE/init"
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
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isolinux.bin    > /tmp/isolinux.bin
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isohdpfx.bin    > /tmp/isohdpfx.bin
    limactl shell br2 -- cat /usr/lib/syslinux/modules/bios/ldlinux.c32 > /tmp/ldlinux.c32
    ISOLINUX_BIN="/tmp/isolinux.bin"
    ISOHDPFX="/tmp/isohdpfx.bin"
    LDLINUX="/tmp/ldlinux.c32"
  elif [[ -f "/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin" ]]; then
    ISOLINUX_BIN="/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin"
    echo "Using isolinux from VMware Fusion"
  fi
fi

[[ -f "$ISOLINUX_BIN" ]] && cp "$ISOLINUX_BIN" "$STAGING/boot/isolinux/"
[[ -f "$LDLINUX" ]]      && cp "$LDLINUX"      "$STAGING/boot/isolinux/"
[[ -f "$ISOHDPFX" ]]     || ISOHDPFX=""

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
  APPEND console=tty0 console=ttyS0,115200 acpi=off clocksource=jiffies tsc=unstable
LABEL 2
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND console=tty0 console=ttyS0,115200 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable
LABEL 3
  KERNEL /boot/bzImage
  INITRD /boot/initrd.img
  APPEND console=tty0 console=ttyS0,115200 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable live.install=1
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
set -e
echo "=== ThinkPad 600X Live Installer ==="
echo
echo "Available disks:"
cat /proc/partitions
echo
echo "Target: /dev/sda (the internal PATA disk). ALL DATA ON IT WILL BE ERASED."
if grep -q 'live.install.auto=1' /proc/cmdline; then
  echo "Unattended mode (live.install.auto=1): proceeding."
else
  printf "Type YES to continue: "
  read confirm
  [ "$confirm" = "YES" ] || { echo "Aborted."; exit 1; }
fi

# Locate the live media (same scan the initramfs uses).
CD=""
for dev in /dev/sr0 /dev/sr1 /dev/sda /dev/sdb /dev/sdc /dev/sdd \
           /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1; do
  [ -b "$dev" ] || continue
  mkdir -p /mnt/src
  if mount -t iso9660 -o ro "$dev" /mnt/src 2>/dev/null; then
    [ -e /mnt/src/boot/bzImage ] && { CD="$dev"; break; }
    umount /mnt/src 2>/dev/null || true
  fi
done
[ -n "$CD" ] || { echo "ERROR: live media not found"; exit 1; }
echo "Live media: $CD"

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
[ -b "$TARGET_PART" ] || { echo "ERROR: /dev/sda1 did not appear"; exit 1; }

echo "Creating ext4 on $TARGET_PART ..."
# syslinux/extlinux 6.03 cannot read directories on a filesystem with
# metadata_csum/orphan_file (and 64bit is pointless on a 40 GB disk), so create
# the root filesystem without those features.
mkfs.ext4 -F -O ^metadata_csum,^orphan_file,^64bit "$TARGET_PART"

mkdir -p /mnt/target
mount "$TARGET_PART" /mnt/target

echo "Copying live files onto $TARGET_PART (~200 MB)..."
cp -a /mnt/src/. /mnt/target/

# Bootloader config for the installed system: boot from the ext4 root.
cat > /mnt/target/boot/extlinux.conf <<'CFG'
DEFAULT linux
PROMPT 0
TIMEOUT 30
LABEL linux
  KERNEL /boot/bzImage
  APPEND root=/dev/sda1 rootfstype=ext4 rw rootwait console=tty0 console=ttyS0,115200 acpi=off clocksource=jiffies tsc=unstable
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
if command -v extlinux >/dev/null 2>&1; then
  echo "Installing extlinux..."
  extlinux --install /mnt/target/boot
else
  echo "WARNING: extlinux not found; HDD may not be bootable"
fi

# Write the syslinux MBR code to sector 0 (first 440 bytes only, so the
# partition table stays intact).
for mbr in /usr/share/syslinux/mbr.bin /usr/lib/syslinux/mbr/mbr.bin; do
  if [ -f "$mbr" ]; then
    dd if="$mbr" of=/dev/sda bs=440 count=1 conv=notrunc 2>/dev/null && break
  fi
done

sync
umount /mnt/target
umount /mnt/src 2>/dev/null || true
echo
echo "Installation complete."
echo "Remove the CD/USB and the system will reboot into the installed HDD."
echo "Login: root / thinkpad600x"
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
echo "Done: $ISO_OUT"
echo "USB:  diskutil unmountDisk /dev/diskN && sudo dd if=$ISO_OUT of=/dev/rdiskN bs=1m"
echo "CD:   hdiutil burn \"$ISO_OUT\" -speed 4"

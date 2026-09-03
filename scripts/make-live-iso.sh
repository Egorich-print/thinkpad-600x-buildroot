#!/bin/bash
# make-live-iso.sh — собрать загрузочный live-CD ISO для ThinkPad 600X
# Требует: xorriso, isolinux, собранный release/rootfs.tar + bzImage
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/release"
STAGING="/tmp/thinkpad-live-staging"
ISO_OUT="/tmp/thinkpad600x-live.iso"

echo "=== Подготовка live-ISO (ISO9660, El Torito, 4x-friendly) ==="
rm -rf "$STAGING" "$ISO_OUT"
mkdir -p "$STAGING/boot/isolinux"

# 1. Распаковать rootfs.tar в корень ISO (это и будет live-система, ro)
echo "Распакую rootfs.tar → $STAGING ..."
tar -xf "$RELEASE_DIR/rootfs.tar" -C "$STAGING"

# 2. Ядро
cp "$RELEASE_DIR/bzImage" "$STAGING/boot/bzImage"
echo "bzImage скопирован"

# 3. Isolinux (из линуксового окружения — передай пути, или скачаю)
ISOLINUX_BIN="/usr/lib/ISOLINUX/isolinux.bin"
ISOHDPFX="/usr/lib/ISOLINUX/isohdpfx.bin"
LDLINUX="/usr/lib/syslinux/modules/bios/ldlinux.c32"
LIBCOM32="/usr/lib/syslinux/modules/bios/libcom32.c32"
LIBUTIL="/usr/lib/syslinux/modules/bios/libutil.c32"

# Если на macOS — файлы в VM
if [[ ! -f "$ISOLINUX_BIN" ]]; then
  # Попробуй взять из VM через limactl
  if limactl shell br2 -- test -f /usr/lib/ISOLINUX/isolinux.bin 2>/dev/null; then
    echo "Копирую isolinux из VM..."
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isolinux.bin > /tmp/isolinux.bin
    limactl shell br2 -- cat /usr/lib/ISOLINUX/isohdpfx.bin > /tmp/isohdpfx.bin
    limactl shell br2 -- cat /usr/lib/syslinux/modules/bios/ldlinux.c32 > /tmp/ldlinux.c32
    limactl shell br2 -- cat /usr/lib/syslinux/modules/bios/libcom32.c32 > /tmp/libcom32.c32
    limactl shell br2 -- cat /usr/lib/syslinux/modules/bios/libutil.c32 > /tmp/libutil.c32
    ISOLINUX_BIN="/tmp/isolinux.bin"
    ISOHDPFX="/tmp/isohdpfx.bin"
    LDLINUX="/tmp/ldlinux.c32"
    LIBCOM32="/tmp/libcom32.c32"
    LIBUTIL="/tmp/libutil.c32"
  elif [[ -f "/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin" ]]; then
    ISOLINUX_BIN="/Applications/VMware Fusion.app/Contents/Resources/isolinux.bin"
    echo "Использую isolinux из VMware Fusion (без ldlinux — нужен полный syslinux)"
  fi
fi

# Копируем загрузчик
if [[ -f "$ISOLINUX_BIN" ]]; then cp "$ISOLINUX_BIN" "$STAGING/boot/isolinux/"; fi
if [[ -f "$LDLINUX" ]]; then cp "$LDLINUX" "$STAGING/boot/isolinux/"; fi
if [[ -f "$LIBCOM32" ]]; then cp "$LIBCOM32" "$STAGING/boot/isolinux/"; fi
if [[ -f "$LIBUTIL" ]]; then cp "$LIBUTIL" "$STAGING/boot/isolinux/"; fi

# isohdpfx for isohybrid (needed for USB, harmless for CD)
if [[ -f /tmp/isohdpfx.bin ]]; then
  ISOHDPFX="/tmp/isohdpfx.bin"
elif [[ -f /usr/lib/ISOLINUX/isohdpfx.bin ]]; then
  ISOHDPFX="/usr/lib/ISOLINUX/isohdpfx.bin"
fi

# 4. Конфиг isolinux — цифры 1/2/3, без menu.c32 (старый BIOS виснет на UI)
cat > "$STAGING/boot/isolinux/isolinux.cfg" <<'EOF'
DEFAULT 1
PROMPT 1
TIMEOUT 0
DISPLAY boot.msg
LABEL 1
  KERNEL /boot/bzImage
  APPEND root=LABEL=THINKPAD600X_LIV rootfstype=iso9660 ro rootwait console=tty1 acpi=off clocksource=jiffies tsc=unstable
LABEL 2
  KERNEL /boot/bzImage
  APPEND root=LABEL=THINKPAD600X_LIV rootfstype=iso9660 ro rootwait console=tty1 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable
LABEL 3
  KERNEL /boot/bzImage
  APPEND root=LABEL=THINKPAD600X_LIV rootfstype=iso9660 ro rootwait console=tty1 acpi=off noapic nolapic nomodeset clocksource=jiffies tsc=unstable init=/sbin/install-live.sh
EOF
cat > "$STAGING/boot/isolinux/boot.msg" <<'EOF'
ThinkPad 600X Live CD (6.12.104, 4x)
1 - Live CDE
2 - Live Safe (acpi=off noapic)
3 - Install to HDD (40GB sda1)

Press 1, 2 or 3 then Enter
EOF

# 5. Скрипт установки (попадёт в live-систему как /sbin/install-live.sh)
mkdir -p "$STAGING/sbin"
cat > "$STAGING/sbin/install-live.sh" <<'EOS'
#!/bin/sh
# Live installer: copy live system from CD/USB to /dev/sda (PATA HDD)
set -e
echo "=== ThinkPad 600X Live Installer ==="
echo "Target: /dev/sda (whole disk will be erased!)"
echo "Press Enter to continue, Ctrl-C to abort"
read dummy

# Find CD/USB source
if [ -b /dev/sr0 ]; then CD=/dev/sr0
elif [ -b /dev/sda ]; then CD=/dev/sr0
else CD=/dev/cdrom; fi
# USB hybrid appears as /dev/sdb or /dev/sda, CD as sr0 — try to detect ISO source
if [ ! -b "$CD" ]; then
  for dev in /dev/sr0 /dev/cdrom /dev/sdb1 /dev/sda1; do
    if mount -o ro "$dev" /mnt 2>/dev/null; then
      if [ -f /mnt/boot/bzImage ]; then CD="$dev"; umount /mnt; break; fi
      umount /mnt 2>/dev/null || true
    fi
  done
fi

# Unmount target if mounted
umount /dev/sda* 2>/dev/null || true

echo "Copying rootfs from $CD to /dev/sda..."
echo "40GB disk: creating MBR + single partition (compatible with old BIOS)..."
if command -v sfdisk >/dev/null 2>&1; then
  printf "label: dos\nstart=2048, type=83, bootable\n" | sfdisk /dev/sda 2>&1 | tail -10
elif command -v fdisk >/dev/null 2>&1; then
  printf "o\nn\np\n1\n2048\n\nw\n" | fdisk /dev/sda 2>&1 | tail -10
fi
partprobe /dev/sda 2>/dev/null || sleep 2
TARGET_PART="/dev/sda1"
if [ ! -b "$TARGET_PART" ]; then TARGET_PART="/dev/sda"; echo "Раздел не появился, использую $TARGET_PART напрямую"; fi

echo "Creating ext4 on $TARGET_PART (40GB)..."
mkfs.ext4 -F "$TARGET_PART" 2>&1 | tail -5
mkdir -p /mnt/target /mnt/cdrom
mount "$TARGET_PART" /mnt/target
mount -o ro "$CD" /mnt/cdrom 2>&1 | head -5 || mount -o ro /dev/sr0 /mnt/cdrom

echo "Copying files (ISO -> ext4, ~200M)..."
cp -a /mnt/cdrom/* /mnt/target/ 2>&1 | tail -20
# Ensure kernel is present
cp /mnt/cdrom/boot/bzImage /mnt/target/boot/bzImage 2>/dev/null || true

# Install extlinux/syslinux
if command -v extlinux >/dev/null 2>&1; then
  echo "Installing extlinux on $TARGET_PART..."
  extlinux --install /mnt/target/boot 2>&1 | tail -5 || true
elif command -v syslinux >/dev/null 2>&1; then
  syslinux --install "$TARGET_PART" 2>&1 | tail -5 || syslinux -i "$TARGET_PART" 2>&1 | tail -5
fi
# MBR (first 440 bytes, keep partition table)
if [ -f /usr/lib/syslinux/mbr/mbr.bin ]; then
  dd if=/usr/lib/syslinux/mbr/mbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
elif [ -f /usr/lib/EXTLINUX/mbr.bin ]; then
  dd if=/usr/lib/EXTLINUX/mbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
elif [ -f /usr/lib/syslinux/mbr/gptmbr.bin ]; then
  dd if=/usr/lib/syslinux/mbr/gptmbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
fi

umount /mnt/target
umount /mnt/cdrom
echo "Done. Remove CD/USB and reboot from HDD."
echo "Login: root / thinkpad600x"
EOS
chmod +x "$STAGING/sbin/install-live.sh"

# 6. Build hybrid ISO (CD + USB via Plop)
echo "Building hybrid ISO (CD+USB)..."
if [[ -f "$ISOHDPFX" ]]; then
  ISOHDPFX_OPT="-isohybrid-mbr $ISOHDPFX"
else
  ISOHDPFX_OPT=""
fi

# На macOS xorriso есть, на VM тоже
if command -v xorrisofs >/dev/null 2>&1; then
  XORRISO=xorrisofs
elif command -v mkisofs >/dev/null 2>&1; then
  XORRISO=mkisofs
else
  XORRISO="/opt/homebrew/bin/xorrisofs"
fi

$XORRISO -o "$ISO_OUT" \
  -R -J -V "THINKPAD600X_LIVE" \
  -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  $ISOHDPFX_OPT \
  "$STAGING" 2>&1 | tail -20

ls -lh "$ISO_OUT"
echo "Готово: $ISO_OUT"
echo "Запись: hdiutil burn \"$ISO_OUT\" -speed 4   или   drutil burn \"$ISO_OUT\""

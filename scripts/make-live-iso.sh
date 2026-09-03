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

# isohdpfx для isohybrid — НЕ используем для CD-RW на старом BIOS 600X (ломает El Torito)
ISOHDPFX=""

# 4. Конфиг isolinux — максимально простой, без menu.c32 (старый BIOS 600X виснет на UI)
cat > "$STAGING/boot/isolinux/isolinux.cfg" <<'EOF'
DEFAULT live
PROMPT 1
TIMEOUT 50
DISPLAY boot.msg
LABEL live
  KERNEL /boot/bzImage
  APPEND root=/dev/sr0 rootfstype=iso9660 ro console=tty1
LABEL install
  KERNEL /boot/bzImage
  APPEND root=/dev/sr0 rootfstype=iso9660 ro console=tty1 init=/sbin/install-live.sh
EOF
cat > "$STAGING/boot/isolinux/boot.msg" <<'EOF'
ThinkPad 600X Live CD
- live    : Live CDE (нажми Enter)
- install : Установить на /dev/sda
EOF

# 5. Скрипт установки (попадёт в live-систему как /sbin/install-live.sh)
mkdir -p "$STAGING/sbin"
cat > "$STAGING/sbin/install-live.sh" <<'EOS'
#!/bin/sh
# Live-установщик: копирует live-систему с CD на /dev/sda (PATA HDD)
set -e
echo "=== ThinkPad 600X Live Installer ==="
echo "Цель: /dev/sda (весь диск будет перезаписан!)"
echo "Нажми Enter для продолжения, Ctrl-C для отмены"
read dummy

# Найти CD
if [ -b /dev/sr0 ]; then CD=/dev/sr0; else CD=/dev/cdrom; fi

# Размонтировать цель если смонтирована
umount /dev/sda* 2>/dev/null || true

echo "Копирую rootfs с $CD на /dev/sda (dd, ~500M)..."
# Мы не можем dd iso9660 напрямую — копируем файлы через tar
# Проще: пересоздать ext2 на /dev/sda и скопировать файлы
# Но у нас есть rootfs.ext2 как файл? В live-ISO его нет отдельно.
# Вместо этого — создаём ext2 и копируем live-файлы
echo "40 ГБ диск: создаю MBR + один раздел на весь диск (совместимо со старым BIOS)..."
if command -v sfdisk >/dev/null 2>&1; then
  printf "label: dos\nstart=2048, type=83, bootable\n" | sfdisk /dev/sda 2>&1 | tail -10
elif command -v fdisk >/dev/null 2>&1; then
  printf "o\nn\np\n1\n2048\n\nw\n" | fdisk /dev/sda 2>&1 | tail -10
fi
partprobe /dev/sda 2>/dev/null || sleep 2
TARGET_PART="/dev/sda1"
if [ ! -b "$TARGET_PART" ]; then TARGET_PART="/dev/sda"; echo "Раздел не появился, использую $TARGET_PART напрямую"; fi

echo "Создаю ext4 на $TARGET_PART (40 ГБ)..."
mkfs.ext4 -F "$TARGET_PART" 2>&1 | tail -5
mkdir -p /mnt/target /mnt/cdrom
mount "$TARGET_PART" /mnt/target
mount -o ro "$CD" /mnt/cdrom 2>&1 | head -5 || mount -o ro /dev/sr0 /mnt/cdrom

echo "Копирую файлы (из ISO в ext4, ~200M)..."
cp -a /mnt/cdrom/* /mnt/target/ 2>&1 | tail -20
# Убедиться что ядро на месте
cp /mnt/cdrom/boot/bzImage /mnt/target/boot/bzImage 2>/dev/null || true

# Ставим syslinux/extlinux
if command -v extlinux >/dev/null 2>&1; then
  echo "Ставлю extlinux на $TARGET_PART..."
  extlinux --install /mnt/target/boot 2>&1 | tail -5 || true
elif command -v syslinux >/dev/null 2>&1; then
  syslinux --install "$TARGET_PART" 2>&1 | tail -5 || syslinux -i "$TARGET_PART" 2>&1 | tail -5
fi
# MBR (первые 440 байт, не трогая таблицу разделов)
if [ -f /usr/lib/syslinux/mbr/mbr.bin ]; then
  dd if=/usr/lib/syslinux/mbr/mbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
elif [ -f /usr/lib/EXTLINUX/mbr.bin ]; then
  dd if=/usr/lib/EXTLINUX/mbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
elif [ -f /usr/lib/syslinux/mbr/gptmbr.bin ]; then
  dd if=/usr/lib/syslinux/mbr/gptmbr.bin of=/dev/sda bs=440 count=1 conv=notrunc 2>&1 | tail -3
fi

umount /mnt/target
umount /mnt/cdrom
echo "Готово. Извлеки CD и перезагрузись с HDD."
echo "Логин: root / thinkpad600x"
EOS
chmod +x "$STAGING/sbin/install-live.sh"

# 6. Собрать ISO
echo "Собираю ISO..."
ISOHDPFX_OPT=""

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

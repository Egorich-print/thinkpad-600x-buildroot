#!/bin/bash
# install-pata.sh — запись образа ThinkPad 600X на PATA-диск / CF-карту
# Использование:
#   ./scripts/install-pata.sh                # интерактив
#   ./scripts/install-pata.sh /dev/disk4     # Mac (diskN, не diskNs1)
#   ./scripts/install-pata.sh /dev/sdb       # Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/release"
IMG="$RELEASE_DIR/rootfs.ext2"
KERNEL="$RELEASE_DIR/bzImage"
SUMS="$RELEASE_DIR/SHA256SUMS.txt"

red()  { printf "\033[31m%s\033[0m\n" "$*"; }
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

if [[ ! -f "$IMG" ]]; then red "Не найден $IMG — сначала собери образ"; exit 1; fi
if [[ ! -f "$SUMS" ]]; then yellow "Нет SHA256SUMS.txt — пропускаю проверку"; else
  echo "Проверка SHA256..."
  (cd "$RELEASE_DIR" && shasum -a 256 -c SHA256SUMS.txt 2>&1 | grep -E "rootfs.ext2|bzImage") || \
  (cd "$RELEASE_DIR" && sha256sum -c SHA256SUMS.txt 2>&1 | grep -E "rootfs.ext2|bzImage")
  green "SHA256 OK"
fi

# Выбор диска
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo ""
  echo "Подключи PATA-диск через USB→IDE / CF→IDE адаптер."
  if [[ "$(uname)" == "Darwin" ]]; then
    diskutil list external 2>&1 | head -50
    echo ""
    read -rp "Введи устройство целиком (например /dev/disk4, НЕ disk4s1): " TARGET
  else
    lsblk -d -o NAME,SIZE,MODEL 2>&1 | head -30
    echo ""
    read -rp "Введи устройство (например /dev/sdb): " TARGET
  fi
fi

if [[ ! -e "$TARGET" ]]; then red "Устройство $TARGET не найдено"; exit 1; fi

# Защита от записи на системный диск
if [[ "$(uname)" == "Darwin" ]]; then
  SYS_DISK="$(diskutil info / 2>&1 | grep "Device Node" | awk '{print $3}' | sed 's/s[0-9]*$//')"
  if [[ "$TARGET" == "$SYS_DISK"* ]]; then red "Отказ: $TARGET — системный диск ($SYS_DISK)"; exit 1; fi
  echo ""; yellow "Цель: $TARGET  ($(diskutil info "$TARGET" 2>&1 | grep "Disk Size" | head -1))"
else
  echo ""; yellow "Цель: $TARGET  ($(lsblk -d -o SIZE,MODEL "$TARGET" 2>&1 | tail -1))"
  if [[ "$TARGET" == "/dev/sda" ]]; then
    read -rp "Это похоже на системный диск /dev/sda — продолжить? [y/N] " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || exit 1
  fi
fi

echo ""
red "ВНИМАНИЕ: все данные на $TARGET будут УНИЧТОЖЕНЫ!"
read -rp "Набери YES для продолжения: " confirm
[[ "$confirm" == "YES" ]] || { echo "Отменено"; exit 1; }

# Размонтировать
echo ""
echo "Размонтирую..."
if [[ "$(uname)" == "Darwin" ]]; then
  diskutil unmountDisk "$TARGET" 2>&1 | tail -5 || true
else
  sudo umount "${TARGET}"* 2>&1 | tail -5 || true
fi

# Запись
echo ""
echo "Запись $IMG → $TARGET (bs=1M)..."
if [[ "$(uname)" == "Darwin" ]]; then
  # rdisk быстрее; sudo нужен
  RAW_TARGET="${TARGET/disk/rdisk}"
  echo "  dd if=$IMG of=$RAW_TARGET bs=1m"
  sudo dd if="$IMG" of="$RAW_TARGET" bs=1m status=progress 2>&1 || sudo dd if="$IMG" of="$RAW_TARGET" bs=1m
  sudo sync
else
  sudo dd if="$IMG" of="$TARGET" bs=1M status=progress
  sudo sync
fi

# Syslinux в MBR (только Linux — на macOS syslinux нет, сделай на 600X или на Linux-хосте)
echo ""
if [[ "$(uname)" == "Darwin" ]]; then
  yellow "На macOS syslinux в MBR не ставлю (нет syslinux)."
  yellow "Два варианта:"
  yellow "  1) Вставь диск в 600X — syslinux уже внутри ext2 (загрузка пойдёт, если BIOS видит MBR от dd)"
  yellow "  2) Или на любом Linux-хосте: sudo syslinux --install $TARGET"
  echo ""
  green "Готово. Извлеки диск: diskutil eject $TARGET"
else
  if command -v syslinux >/dev/null 2>&1; then
    echo "Ставлю syslinux в MBR..."
    # isolinux/syslinux 6.x: --install пишет MBR; на некоторых системах нужен -i
    sudo syslinux --install "$TARGET" 2>&1 || sudo syslinux -i "$TARGET" 2>&1 || true
    # Копируем mbr.bin если нужно
    if [[ -f /usr/lib/syslinux/mbr/mbr.bin ]]; then
      sudo dd if=/usr/lib/syslinux/mbr/mbr.bin of="$TARGET" bs=440 count=1 conv=notrunc 2>&1 | tail -3 || true
    fi
    green "syslinux установлен"
  else
    yellow "syslinux не найден — установи: sudo apt install syslinux"
    yellow "Затем: sudo syslinux --install $TARGET"
  fi
fi

echo ""
green "Готово. Вставь диск в ThinkPad 600X (Primary Master), в BIOS поставь IDE первым."
echo "Логин: root / пароль: thinkpad600x  —  CDE: startx /usr/dt/bin/Xsession"

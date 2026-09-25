# INSTALL — ThinkPad 600X (2645-4EU)

Как собрать носитель, загрузить live-систему и поставить её на внутренний
PATA-диск 600X.

## Что собирается

| Артефакт | Размер | Назначение |
|----------|-------:|-----------|
| `/tmp/thinkpad600x-live.iso` | ~270 MiB + bootloader/initrd overhead | гибридный live CD/USB (El Torito + isohybrid MBR) |
| `release/bzImage` | ~3.8 MB | ядро Linux 6.12.104 LTS (i686 pentium3) |
| `release/rootfs.tar` | ~270 MB | корневое дерево (CDE + X11 + приложения) |
| `release/rootfs.ext2` | 512 MB | ext4-образ корня (для host-side записи) |

SHA256 — в `release/SHA256SUMS.txt`.

Сборка ISO: `scripts/make-live-iso.sh` (нужны `xorriso`, `cpio`, `gzip`;
isolinux берётся с хоста или из lima VM `br2`).

## Почему в образе есть initramfs

Ядро **не понимает `root=LABEL=`** (парсер `block/early-lookup.c` принимает только
`PARTUUID=`, `PARTLABEL=`, `/dev/<имя>` и `MAJOR:MINOR`). Поэтому один и тот же
образ не может заранее назвать свой корень: на CD это `/dev/sr0`, на USB —
`/dev/sdX`. Маленький initramfs (`board/thinkpad600x/initramfs/init`) сам находит
носитель по содержимому, монтирует его и накладывает **overlayfs** (записываемый
корень в RAM), после чего `switch_root`.

## Запись носителя

### USB-флешка (загрузка live-образа)

600X не умеет грузиться с USB штатным BIOS — нужен **Plop Boot Manager**
(`plpbt.iso`/`plpbt.img`, ~544 KB). Порядок:

```sh
# 1. записать live-образ на флешку (macOS)
diskutil list                       # найти флешку, напр. /dev/disk6
diskutil unmountDisk /dev/disk6
sudo dd if=/tmp/thinkpad600x-live.iso of=/dev/rdisk6 bs=1m
sudo sync

# 2. записать Plop на CD-R(W) или дискету
hdiutil burn /path/to/plpbt.iso -speed 4
```

На 600X: `Plop CD` в UltraSlimBay + флешка в USB-порт → BIOS → CD первым →
в меню Plop выбрать **USB**.

### CD-R

```sh
hdiutil burn /tmp/thinkpad600x-live.iso -speed 4
```

Если CD-RW на приводе 600X даёт `MEDIUM ERROR`, предпочтителен CD-R @ 4x.

## Загрузка live-системы

Меню isolinux (цифры + Enter):

| Клавиша | Режим |
|---------|-------|
| `1` | Live CDE (`acpi=off`, `clocksource=jiffies`, `tsc=unstable`) |
| `2` | Live Safe (+ `noapic nolapic nomodeset`) |
| `3` | **Install to internal HDD** (`/dev/sda`, `live.install=1`) |

Порядок `console=` в live- и установленном cmdline — `console=ttyS0,115200 console=tty0`:
последний `console=` становится `/dev/console`, поэтому приглашение установщика
выводится и считывается на VGA-консоли.

`tty1` автоматически запускает CDE через `/usr/sbin/autostart-cde`. На `ttyS0`
работает getty; вход выполняется как `root` с пустым паролем (просто Enter).

## Установка на HDD (пункт 3)

Поддерживаемый путь установки — пункт `3` live-образа, который добавляет
`live.install=1`. Скрипт `/sbin/install-live.sh`:

1. показывает `/proc/partitions` и выводит `Type YES to continue:`; для ручной
   установки нужно ввести ровно `YES`;
2. `sfdisk` создаёт MBR + один загрузочный раздел на `/dev/sda`;
3. `mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit` (extlinux 6.03 не читает
   каталоги с `metadata_csum`/`orphan_file`);
4. копирует live-дерево и пишет `/boot/extlinux.conf` + `/boot/syslinux.cfg`;
5. запускает `extlinux --install /mnt/target/boot` и записывает syslinux MBR (первые 440 байт
   сектора 0), не затирая таблицу разделов;
6. перезагружается (`reboot -f`).

Для unattended-варианта к параметрам ядра добавляется
`live.install.auto=1`; тогда подтверждение `YES` не запрашивается.

## Первая загрузка с HDD

1. CDE автоматически запускается на `tty1`; на `ttyS0` доступен getty.
2. Вход `root` — **без пароля** (просто Enter).
3. Сеть: `udhcpc -i eth0` (или статически).
4. Wi-Fi (TL-WN727N, MediaTek MT7601U, `148f:7601`): `modprobe mt7601u`, затем
   `wpa_supplicant`/`iw`.
5. Звук (CS46xx): прошивка в `/lib/firmware/cs46xx/` (см. ниже); проверка —
   `aplay -l` / `speaker-test`. Вывод звука на реальном 600X пока не подтверждён.
6. Выключение: `poweroff` / перезагрузка: `reboot`.

## Пересборка компонентов

### Прошивка звука CS46xx (несвободная, не в репозитории)

`scripts/fetch-cs46xx-firmware.sh` нужно запустить один раз перед сборкой: скрипт
скачивает `alsa-firmware` и кладёт
`cs46xx/{ba1,cwc4630,cwcasync,cwcbinhack,cwcdma,cwcsnoop}` в overlay.
Без этого прошивка в итоговом образе отсутствует; вывод звука на реальном 600X
остаётся непроверенным.
```sh
./scripts/fetch-cs46xx-firmware.sh
```

### Ядро + rootfs (lima VM)

```sh
limactl shell br2 -- bash -c 'cd ~/buildroot && \
  make O=~/br2-out BR2_EXTERNAL="$HOME/thinkpad-600x-buildroot" thinkpad600x_defconfig && \
  make O=~/br2-out BR2_EXTERNAL="$HOME/thinkpad-600x-buildroot" -j10'
# скопировать bzImage, rootfs.tar и rootfs.ext2 из выходного каталога Buildroot в release/
```

### i686 `extlinux` (если нужно пересобрать overlay-бинарь)

Buildroot собирает установщики syslinux под **хост** (aarch64), поэтому `extlinux`
для target пересобирается вручную из дерева syslinux:

```sh
limactl shell br2 -- bash -c '
cd ~/br2-out/build/syslinux-6.03
export PATH=~/br2-out/host/bin:$PATH
H=~/br2-out/host
rm -f bios/extlinux/*.o bios/extlinux/extlinux
make ASCIIDOC_OK=-1 A2X_XML_OK=-1 \
  CC=i686-buildroot-linux-gnu-gcc LD=i686-buildroot-linux-gnu-ld \
  OBJCOPY=i686-buildroot-linux-gnu-objcopy AS=i686-buildroot-linux-gnu-as \
  NASM=$H/bin/nasm CC_FOR_BUILD=i686-buildroot-linux-gnu-gcc \
  CFLAGS_FOR_BUILD="-Os -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE" \
  LDFLAGS_FOR_BUILD="" PYTHON=$H/bin/python3 bios || true
file bios/extlinux/extlinux   # должен быть ELF 32-bit i386
'
# скопировать в board/thinkpad600x/rootfs-overlay/usr/sbin/extlinux
```

`mbr.bin` берётся из собранного syslinux и копируется в
`board/thinkpad600x/rootfs-overlay/usr/share/syslinux/`.

## Диагностика

| Симптом | Причина / решение |
|--------|-------------------|
| `VFS: Cannot open root device "LABEL=..."` | `root=LABEL=` не поддерживается ядром — используется initramfs |
| `devtmpfs: error mounting -2` | корень не смонтирован (initramfs не нашёл носитель) |
| `No configuration file found` (extlinux) | ext4 с `metadata_csum`/`orphan_file` — пересоздать ФС |
| `SYSLINUX ... boot:` без ядра | нет `ldlinux.c32`/`extlinux.conf` в `/boot` |
| USB не виден при загрузке | включить `USB_STORAGE=y` (уже включено) |
| Зависание на BogoMIPS | `CONFIG_NO_HZ_IDLE` не задан, `clocksource=jiffies` |

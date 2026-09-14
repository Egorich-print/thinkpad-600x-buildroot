# INSTALL — ThinkPad 600X (2645-4EU)

Как собрать носитель, загрузить live-систему и поставить её на внутренний
PATA-диск 600X.

## Что собирается

| Артефакт | Размер | Назначение |
|----------|-------:|-----------|
| `/tmp/thinkpad600x-live.iso` | ~210 MB | гибридный live CD/USB (El Torito + isohybrid MBR) |
| `release/bzImage` | ~3.8 MB | ядро Linux 6.12.104 LTS (i686 pentium3) |
| `release/rootfs.tar` | ~212 MB | корневое дерево (CDE + X11 + приложения) |
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

### USB-флешка (основной путь для 600X)

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

CD-RW на убитом приводе 600X даёт `MEDIUM ERROR`; предпочтителен CD-R @ 4x.

## Загрузка live-системы

Меню isolinux (цифры + Enter):

| Клавиша | Режим |
|---------|-------|
| `1` | Live CDE (`acpi=off`, `clocksource=jiffies`) |
| `2` | Live Safe (+ `noapic nolapic nomodeset`) |
| `3` | **Install to internal HDD** (`/dev/sda`) |

Логин live-системы: `root` **без пароля** (пустой пароль — Enter). CDE:
`startx /usr/dt/bin/Xsession`.

## Установка на HDD (пункт 3)

Скрипт `/sbin/install-live.sh`:

1. показывает `/proc/partitions` и спрашивает подтверждение (`YES`);
2. `sfdisk` создаёт MBR + один загрузочный раздел на `/dev/sda`;
3. `mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit` (extlinux 6.03 не читает
   каталоги с `metadata_csum`/`orphan_file`);
4. копирует live-дерево, пишет `/boot/extlinux.conf` + `syslinux.cfg`;
5. `extlinux --install /boot` (VBR) и `mbr.bin` в сектор 0;
6. перезагружается.

Автономный режим для тестов: добавить `live.install.auto=1` в параметры ядра.

## Первая загрузка с HDD

1. Логин `root` — **без пароля** (просто Enter).
2. Сеть: `udhcpc -i eth0` (или статически).
3. CDE: `startx /usr/dt/bin/Xsession`.
4. Wi-Fi (TL-WN727N): `modprobe mt7601u`, затем `wpa_supplicant`/`iw`.
5. Звук (CS46xx): прошивка в `/lib/firmware/cs46xx/` (см. ниже); проверка —
   `aplay -l` / `speaker-test`.
6. Выключение: `poweroff` / перезагрузка: `reboot`.

## Пересборка компонентов

### Прошивка звука CS46xx (несвободная, не в репозитории)

`scripts/fetch-cs46xx-firmware.sh` скачивает `alsa-firmware` и кладёт
`cs46xx/{ba1,cwc4630,cwcasync,cwcbinhack,cwcdma,cwcsnoop}` в overlay:
```sh
./scripts/fetch-cs46xx-firmware.sh
```

### Ядро + rootfs (lima VM)

```sh
limactl shell br2 -- bash -c "cd ~/buildroot && \
  make O=~/br2-out BR2_EXTERNAL=/Users/<you>/.../thinkpad-600x-buildroot thinkpad600x_defconfig && \
  make O=~/br2-out BR2_EXTERNAL=/Users/<you>/.../thinkpad-600x-buildroot -j10"
# скопировать images/{bzImage,rootfs.tar,rootfs.ext2} в release/
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

`mbr.bin` копируется из `~/br2-out/images/syslinux/mbr.bin` в
`board/thinkpad600x/rootfs-overlay/usr/share/syslinux/`.

## Диагностика

| Симптом | Причина / решение |
|--------|-------------------|
| `VFS: Cannot open root device "LABEL=..."` | `root=LABEL=` не поддерживается ядром — используется initramfs |
| `devtmpfs: error mounting -2` | корень не смонтирован (initramfs не нашёл носитель) |
| `No configuration file found` (extlinux) | ext4 с `metadata_csum`/`orphan_file` — пересоздать ФС |
| `SYSLINUX ... boot:` без ядра | нет `ldlinux.c32`/`extlinux.conf` в `/boot` |
| USB не виден при загрузке | включить `USB_STORAGE=y` (уже включено) |
| Зависание на BogoMIPS | `NO_HZ_IDLE=n`, `clocksource=jiffies` |

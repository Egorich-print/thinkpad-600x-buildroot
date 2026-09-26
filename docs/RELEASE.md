# RELEASE — IBM ThinkPad 600X minimal CDE workstation

Buildroot-образ для IBM ThinkPad 600X (2645-4EU): Pentium III 500 MHz, 64 MB RAM,
i686, glibc, CDE (Common Desktop Environment) + X11.

## Final status

- **Собрано и ПРОВЕРЕНО (QEMU, `-cpu pentium3`, 64 MB, TCG)**:
  - Boot, BusyBox userspace, eth0/DHCP-конфигурация, SSH (dropbear) — Level 1–4.
  - Xorg 21.1.24 запускается (modesetting/KMS; для этого добавлен `DRM_BOCHS`) — Level 5.
  - CDE-сессия запускается: `dtsession` + `dtwm` работают (startx → Xsession) — Level 6.
  - `scripts/qemu_test.sh` — smoke test: `IMGDIR` по умолчанию `release/`, QEMU
    работает с `-snapshot=on`, ждёт SSH-порт и запускает диагностику через
    `sshpass`, если он установлен.
  - Бинарный аудит: модель `i686` (`-march=pentium3`, MMX+SSE, БЕЗ SSE2);
    SIMD (SSE2/AVX) есть только в runtime-cpuid-диспетчеризуемых библиотеках
    (jpeg-turbo, OpenSSL, gnulib/pixman/imlib2/mpg123) — на PIII они выбирают
    MMX/не-SIMD путь. Отдельно: `vpxor`(AVX) в coreutils — из gnulib (12× `cpuid`
    в бинаре подтверждают runtime-диспетчеризацию).
- **Оптимизации**: `-march=pentium3 -mtune=pentium3 -O2` (пользовательское),
  ядро `CONFIG_CC_OPTIMIZE_FOR_SIZE` (`-Os`), `CONFIG_MPENTIUMIII`.
  Модель вытеснения не настраивается: в `board/thinkpad600x/linux.config` опции
  `PREEMPT` нет, действует kernel-default `CONFIG_PREEMPT_NONE=y`; подробности и
  доказательства — в `docs/OPTIMIZATION.md` («Preemption: что на самом деле»).
- Аппаратная проверка NeoMagic и CS46xx на физическом 600X не выполнена.

## Измеренные значения (RAM, QEMU `-m 64`)

| Профиль | Использовано (MB) | Свободно (MB) |
|---------|------------------:|--------------:|
| Консоль idle | **8** | 30 |
| X11 (Xorg) | **~10** | — |
| CDE idle (dtsession+dtwm) | **16** | 25 (available) |
| + бrowser/офис | ~40 (оценка) | — |

(Подробнее — `docs/MEMORY.md`.)

## Размер

| Артефакт | Размер |
|----------|-------:|
| `bzImage` | ≈3.7 MiB (текущий release-артефакт, ядро -Os) |
| `rootfs.ext2` | 512 MiB (файловая система; не сырой диск) |
| `rootfs.tar` | ≈253 MiB |
| `/tmp/thinkpad600x-live.iso` | ≈252 MiB; собирается по требованию, не отслеживается |

Значения приблизительные; точные лежат в `release/` и `release/SHA256SUMS.txt`.

`rootfs.ext2` — filesystem image без таблицы разделов и bootloader'а; его нельзя
считать готовым raw-диском для установки. Поддерживаемая установка выполняется
через live-образ, пункт меню 3.

## Точный build

На свежем checkout перед сборкой один раз выполнить (firmware несвободная и не
отслеживается в git):

```sh
./scripts/fetch-cs46xx-firmware.sh
```

Сборка выполняется на Linux aarch64 host (lima VM `br2`):

```sh
make O=$HOME/br2-out BR2_EXTERNAL=/abs/path/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out BR2_EXTERNAL=/abs/path/thinkpad-600x-buildroot -j10
```

После build скопировать `bzImage`, `rootfs.ext2` и `rootfs.tar` из выхода
Buildroot в `release/`, затем перегенерировать отслеживаемый manifest:

```sh
(cd release && sha256sum bzImage rootfs.ext2 rootfs.tar > SHA256SUMS.txt)
```

На macOS эквивалент — `shasum -a 256`. После этого live ISO строится отдельно
по требованию:

```sh
./scripts/make-live-iso.sh
```

Скрипт собирает initramfs из `board/thinkpad600x/initramfs/init`, проверяет
`isolinux.bin`, `ldlinux.c32` и `isohdpfx.bin`, добавляет в ISO
`/sbin/install-live.sh`, создаёт checksum `/tmp/thinkpad600x-live.iso.sha256`
и печатает команды для USB и CD. ISO не отслеживается в git.

## Оптимизационный профиль

- Toolchain: gcc 14.4.0, `i686-buildroot-linux-gnu`, `-march=pentium3`,
  `-mtune=pentium3`, `-O2`, glibc.
- Kernel 6.12.104: `CONFIG_MPENTIUMIII`, `SMP` off, `CONFIG_CC_OPTIMIZE_FOR_SIZE`.
  Опция `PREEMPT` не задана → `CONFIG_PREEMPT_NONE=y` по умолчанию ядра.
  `CONFIG_PREEMPT_DYNAMIC=y` тоже включён по умолчанию (arm64
  `HAVE_PREEMPT_DYNAMIC_CALL`), но это лишь возможность сменить модель через
  `preempt=` в cmdline, а не признак того, что вытеснение динамическое; в
  дереве `preempt=` не встречается.
- FS: создаваемый `rootfs.ext2` — это ext4 несмотря на имя (`BR2_TARGET_ROOTFS_EXT2_4=y`,
  `CONFIG_EXT4_USE_FOR_EXT2=y`); `noatime` устанавливается в fstab инсталлятора.
- И создаваемый `rootfs.ext2`, и инсталлятор создают ext4 без `metadata_csum`,
  `orphan_file` и `64bit`; это задано в том числе через
  `BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS`.
- LTO / -O3 / -Ofast / PGO: **не применены глобально** — см. `docs/OPTIMIZATION.md`.

## CDE

- CDE 2.5.3 (исходники), OpenMotif 2.3.8, `--prefix=/usr/dt` (канонический layout).
- Запуск: `tty1` → `/usr/sbin/autostart-cde` → `startx` без клиентского аргумента →
  `/root/.xinitrc` → `dtwm` + `/usr/dt/bin/Xsession` → `dtsession`.
- `dtlogin` (CDE) и `rpcbind` (`BR2_PACKAGE_RPCBIND`) присутствуют в образе;
  `dtlogin` не используется текущим console-процессом, который запускает CDE
  напрямую.
- Из CDE исключены: dtksh (нужен tcl/A&T ksh), dtmail, dtcm, dtappbuilder, dtinfo,
  dthelp, dtdocbook, localized (NLS), ttsnoop, tttypes.

## Приложения

dtterm, dtfile, dtpad, dtcalc, dtsession/dtwm (CDE) · dillo, links, lynx
(браузеры) · mutool + mupdf-x11 + pdftotext (PDF) · feh (изображения) · mpg123
(аудио) · mc (файл-менеджер TUI) · nano, mg, dtpad (редакторы) · btop (монитор) ·
fastfetch (системная инфа) · antiword (.doc) · dropbear (SSH).

Пакеты NEdit, smartmontools, Ted, NetSurf и surf в текущий образ не входят.
Bluetooth/BlueZ также не включены: в текущем `board/thinkpad600x/linux.config`
отсутствует BT subsystem, а соответствующие пакеты Buildroot не выбраны.

## Tailscale / Amnezia / Rust

- Tailscale: в базовый образ не входит. В Buildroot 2026.05.2 есть пакетный символ
  `BR2_PACKAGE_TAILSCALE` (рецепт фиксирует Tailscale 1.78.1), но
  `configs/thinkpad600x_defconfig` его не выбирает; geode/softfloat и RAM ~40–80 MB
  остаются внешней feasibility-оценкой, а не измеренным результатом.
- Amnezia 5.0.1.5: GUI невозможен (Qt6 x86_64-only). AmneziaWG (C) + awg-tools
  возможны в принципе, но **не реализованы и недоступны** в этом tree: символы
  `BR2_PACKAGE_AWG`/`BR2_PACKAGE_AWG_TOOLS` не существуют, а `CONFIG_TUN` и
  `CONFIG_WIREGUARD` не включены.
- Rust: target-side native tools не поставляются; default Buildroot i686 требует
  SSE2, а принятое исключение — явный `i586-unknown-linux-gnu` (ADR-010).

## Known limitations

- **X11 на реальном 600X**: NeoMagic использует legacy `neofb`/DDX-путь, без
  DRM/KMS. При full RELRO helper-модули legacy DDX загружаются через lazy
  `dlopen`; реализованный workaround — preload `vgahw`, `int10`, `fbdevhw`,
  `shadow` и `shadowfb` в `etc/X11/xorg.conf`. Это единственная заявленная
  реализованная правка; NeoMagic не объявляется ни сломанным, ни аппаратно
  проверенным. QEMU проверяет modesetting+bochs, а не физический NeoMagic-путь.
- Браузер dillo — без JS (осознанно).
- IrDA не поддерживается (удалён из ядра 4.17).

## SHA256

`release/SHA256SUMS.txt` отслеживается в git и содержит `bzImage`, `rootfs.ext2`
и `rootfs.tar`. Бинарные release-файлы не отслеживаются; manifest нужно
перегенерировать после копирования результатов Buildroot. SHA-файл live ISO
создаётся отдельно в `/tmp/thinkpad600x-live.iso.sha256` и не входит в git.

## Установка / recovery

Поддерживаемая установка выполняется не записью `rootfs.ext2` на диск, а через
live ISO и пункт меню `3` (`live.install=1`). Сначала собрать ISO по инструкции
выше, затем записать его на USB или CD:

```sh
diskutil unmountDisk /dev/diskN
sudo dd if=/tmp/thinkpad600x-live.iso of=/dev/rdiskN bs=1m
hdiutil burn /tmp/thinkpad600x-live.iso -speed 4
```

Меню isolinux содержит `1` — Live CDE, `2` — Live Safe
(`noapic`/`nolapic`/`nomodeset`) и `3` — Install to internal HDD. Installer
создаёт MBR и `/dev/sda1`, затем ext4 с
`-O ^metadata_csum,^orphan_file,^64bit`, копирует live-дерево и устанавливает
extlinux. Последний `console=` становится `/dev/console`, поэтому рабочий порядок
— `console=ttyS0,115200 console=tty0`.

Ядро не разрешает `root=LABEL=`, поэтому live-загрузка использует initramfs с
поиском носителя по содержимому и RAM-backed overlayfs. Подробности меню и
инсталлятора — в `docs/DEPLOY.md`.

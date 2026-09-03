# RELEASE — IBM ThinkPad 600X minimal CDE workstation

Buildroot-образ для IBM ThinkPad 600X (2645-4EU): Pentium III 500 MHz, 64 MB RAM,
i686, glibc, CDE (Common Desktop Environment) + X11.

## Final status

- **Собрано и ПРОВЕРЕНО (QEMU, `-cpu pentium3`, 64 MB, TCG)**:
  - Boot, BusyBox userspace, сеть (DHCP), SSH (dropbear) — Level 1–4.
  - Xorg 21.1.24 запускается (modesetting/KMS; для этого добавлен `DRM_BOCHS`) — Level 5.
  - CDE-сессия запускается: `dtsession` + `dtwm` работают (startx → Xsession) — Level 6.
  - Бинарный аудит: модель `i686` (`-march=pentium3`, MMX+SSE, БЕЗ SSE2);
    SIMD (SSE2/AVX) есть только в runtime-cpuid-диспетчеризуемых библиотеках
    (jpeg-turbo, OpenSSL, gnulib/pixman/imlib2/mpg123) — на PIII они выбирают
    MMX/не-SIMD путь. Отдельно: `vpxor`(AVX) в coreutils — из gnulib (12× `cpuid`
    в бинаре подтверждают runtime-диспетчеризацию).
- **Оптимизации**: `-march=pentium3 -mtune=pentium3 -O2` (пользовательское),
  ядро `CONFIG_CC_OPTIMIZE_FOR_SIZE` (`-Os`), `CONFIG_MPENTIUMIII`.

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
| `bzImage` | ~4.9 MB (ядро -Os) |
| `rootfs.ext2` | 512 MB (резерв под рост) |
| `rootfs.tar` | ~210 MB |

## Точный build

```sh
# на Linux aarch64 host (lima VM br2):
make O=$HOME/br2-out BR2_EXTERNAL=/abs/path/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out BR2_EXTERNAL=/abs/path/thinkpad-600x-buildroot -j10
```

## Оптимизационный профиль

- Toolchain: gcc 14.4.0, `i686-buildroot-linux-gnu`, `-march=pentium3`,
  `-mtune=pentium3`, `-O2`, glibc.
- Kernel 6.18.7: `CONFIG_MPENTIUMIII`, `SMP` off, `CONFIG_CC_OPTIMIZE_FOR_SIZE`,
  `PREEMPT_DYNAMIC`.
- FS: ext2 (через ext4-драйвер), `noatime` в fstab.
- LTO / -O3 / -Ofast / PGO: **не применены глобально** — см. `docs/OPTIMIZATION.md`.

## CDE

- CDE 2.5.3 (исходники), OpenMotif 2.3.8, `--prefix=/usr/dt` (канонический layout).
- Запуск: `startx /usr/dt/bin/Xsession` → dtsession → dtwm (+ dtterm/dtfile/dtpad).
- Из CDE исключены: dtksh (нужен tcl/A&T ksh), dtmail, dtcm, dtappbuilder, dtinfo,
  dthelp, dtdocbook, dtlogin (greeter), localized (NLS), ttsnoop, tttypes.

## Приложения

dtterm, dtfile, dtpad, dtcalc, dtsession/dtwm (CDE) · dillo (браузер) · mutool +
mupdf-x11 (PDF) · feh (изображения) · mpg123 (аудио) · mc (файл-менеджер TUI) ·
nano (редактор) · btop (монитор) · fastfetch (системная инфа) · antiword (.doc) ·
lynx (текст-браузер) · dropbear (SSH).

## Tailscale / Amnezia / Rust

- Tailscale: частично (geode-бинарь `GO386=softfloat`; RAM ~40–80 MB = критично).
- Amnezia 5.0.1.5: GUI невозможен (Qt6 x86_64-only); AmneziaWG (C) + awg-tools — CLI.
- Rust: только кросс-компиляция (`i586-unknown-linux-gnu`), нативный — невозможен.

## Known limitations

- **X11 на реальном 600X**: NeoMagic не имеет DRM/KMS-драйвера; легаси DDX-драйвер
  `neomagic` в xorg-server 21.x сломан (undefined symbols `vgaHW*`). Для 600X нужен
  патч/старый xorg или fbdev-фоллбэк. В QEMU X работает через modesetting+bochs.
- Браузер dillo — без JS (осознанно).
- IrDA не поддерживается (удалён из ядра 4.17).

## SHA256

См. `release/SHA256SUMS.txt`.

## Установка / recovery

`docs/INSTALL.md` (macOS dd + Linux dd + CF-IDE + syslinux + первый запуск + recovery).
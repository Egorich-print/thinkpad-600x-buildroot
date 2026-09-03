# INSTALL — записать образ на IBM ThinkPad 600X

Ниже — как записать собранный образ `thinkpad600x-buildroot` на реальный
IBM ThinkPad 600X (2645-4EU). Образ — это **raw ext2 root-filesystem**
(`rootfs.ext2`) + отдельное ядро (`bzImage`). Для прямой загрузки на железе
нужен загрузчик (syslinux) в MBR.

> ⚠️ Запись raw-образа УНИЧТОЖАЕТ ВСЕ ДАННЫЕ на выбранном диске.
> Дважды проверь имя диска перед записью.

## Что входит в образ

| Файл | Размер | Назначение |
|------|-------:|-----------|
| `rootfs.ext2` | 512 MB | ext2 корневая ФС (CDE + X11 + приложения) |
| `bzImage` | ~4.9 MB | ядро 6.18.7 (i686 pentium3) |
| `rootfs.tar` | ~210 MB | то же дерево архивированное |

SHA256 — в `release/SHA256SUMS.txt`.

## Проверка контрольной суммы

### macOS
```sh
shasum -a 256 rootfs.ext2 bzImage
# сверить с release/SHA256SUMS.txt
```

### Linux
```sh
sha256sum rootfs.ext2 bzImage
```

## Способ A — raw-запись ext2 прямо на PATA-диск

Самый простой способ для 600X: ext2-ФС пишется НАЧИНАЯ С НАЧАЛА диска (без
таблицы разделов). Ядро потом грузится загрузчиком.

### macOS (host)

1. Узнай устройство диска (подключи диск через USB-IDE/IDE-адаптер):
   ```sh
   diskutil list
   # найди диск (НЕ том!): /dev/disk4 (не /dev/disk4s1)
   ```
2. Размонтируй ВСЕ тома диска:
   ```sh
   diskutil unmountDisk /dev/disk4
   ```
3. Запиши ext2-ФС:
   ```sh
   sudo dd if=rootfs.ext2 of=/dev/rdisk4 bs=1m
   # rdisk = raw device (быстрее); укажи ДИСК, не срез
   sudo sync
   diskutil eject /dev/disk4
   ```

### Linux (host)

```sh
# 1. найди диск: lsblk (например /dev/sdb)
# 2. размонтируй: umount /dev/sdb*
# 3. запись:
sudo dd if=rootfs.ext2 of=/dev/sdb bs=1M status=progress
sync
```

## Способ B — CF/IDE адаптер (или PATA→USB)

То же самое, только в качестве диска — CompactFlash карта через CF-to-IDE
адаптер. Запись как в способе A. 600X грузится с любого IDE-устройства, которое
BIOS видит как "Primary Master".

## Загрузчик (syslinux)

Для автозагрузки ядра на 600X в MBR нужен syslinux. В проекте есть
`scripts/syslinux.cfg`:

```sh
# после записи ext2 (Linux host, диск /dev/sdb) установи syslinux в MBR:
# (это кладёт загрузчик; ядро/конфиг уже внутри ext2 в /bzImage)
sudo syslinux --install /dev/sdb   # требует смонтированного? нет — пишет MBR
```

В `scripts/syslinux.cfg` `KERNEL /bzImage APPEND root=/dev/sda rw console=tty1`.
На реальной машине консоль — `console=tty1` (VGA), не `ttyS0`.

## Подготовка к первому включению (BIOS/железо)

1. Установи HDD/CF в отсек (или UltraBay).
2. В BIOS (F1 при старте ThinkPad): **Startup → Boot** — поставь IDE/HDD первым.
3. Убедись, что нет пароля на HDD (Hard Disk Password в BIOS).
4. Компьютер 600X НЕ грузится с USB — только IDE/PATA (или CF-IDE).
5. Дисплей 1024×768 — NeoMagic; ядро использует `neofb` (встроен =y).

## Первая загрузка

1. Логин: `root`, пароль: `thinkpad600x` (СРАЗУ смени: `passwd`).
2. Сеть (Ethernet/PCMCIA): `udhcpc -i eth0` или настроить static.
3. Запуск CDE: `startx /usr/dt/bin/Xsession`.
4. Терминал: `dtterm`; файл-менеджер: `dtfile`; редактор: `dtpad` / `nano`.
5. Браузер: `dillo`; PDF: `mupdf-x11`; изображения: `feh`; музыка: `mpg123`.
6. Мониторинг: `btop`, `fastfetch`.
7. Выключение: `poweroff` / `reboot`.

## SSH

```sh
# dropbear уже запущен (S50dropbear). Подключение:
ssh -p 22 root@<ip>   # пароль thinkpad600x (смени!)
# или по ключу: ключ в /root/.ssh/authorized_keys
```

## Tailscale (опционально)

См. `docs/TAILSCALE.md`. Для PIII нужен статический `geode`-бинарь
(`GO386=softfloat`), режим `--tun=userspace-networking`.

## AmneziaWG (опционально)

`docs/AMNEZIA.md`: CLI через `amneziawg-linux-kernel-module` (C) + `amneziawg-tools`.

## Восстановление, если CDE не стартует

1. Ctrl-Alt-F1 → консоль; логин root.
2. Лог Xorg: `cat /var/log/Xorg.0.log`.
3. Лог CDE: `cat /root/.dt/startlog /root/.dt/errorlog`.
4. Кернел-лог: `dmesg | tail`.
5. Проверка ФС: `fsck.ext2 -f /dev/root` (с живого носителя).
6. Перезапуск вручную: `Xorg :0 -config /etc/X11/xorg.conf &` → `DISPLAY=:0 /usr/dt/bin/Xsession &`.
7. Полная перезапись образа — способ A.
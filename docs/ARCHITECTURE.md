# Architecture

```
                       +---------------------------+
                       |  Applications            |
                       |  NEdit  dtfile   dtterm  |
                       |  Dillo  MuPDF   feh      |
                       |  lynx   mc      mpg123   |
                       |  antiword  dropbear      |
                       |  fastfetch  btop         |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  CDE 2.5.3                |
                       |  dtsession -> dtwm (WM)   |
                       |  (Xsession, ksh/mksh)     |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  Xorg + neomagic (DDX)    |
                       |  libX11/…/Xt/Xm(Motif)    |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  core userspace           |
                       |  BusyBox init + mdev      |
                       |  glibc + libtirpc + lmdb  |
                       +------------+--------------+
                                    |
                       +------------+--------------+
                       |  Linux 6.18.7 (i686)      |
                       |  ata_piix neofb rt2800usb |
                       |  btusb thinkpad_acpi …    |
                       +------------+--------------+
```

## Boot flow

1. BIOS → bootloader (Syslinux) → `bzImage`.
2. Kernel mounts `/` (ext2 on `/dev/sda`) with `devtmpfs`.
3. BusyBox `init` reads `/etc/inittab`: mounts proc/sysfs/devpts/tmpfs, runs `rcS`.
4. `rcS` → run-parts `/etc/init.d/`: syslogd, klogd, mdev, `S40network` (DHCP),
   dropbear, crond.
5. `getty` on `tty1` (VGA) and `ttyS0` (dock/QEMU).
6. User runs `startx /usr/dt/bin/Xsession`.
7. `Xsession` (mksh): `dtsearchpath` → search paths → `ttsession` → `dtsession`.
8. `dtsession` starts `dtwm` (there is no dtlogin, no rpcbind, no rpc.ttdbserver).

## Key dependencies

- **CDE** requires OpenMotif (libXm/libMrm/libUil), libtirpc (SunRPC), LMDB
  (dtinfo/mmdb), libjpeg, and the standard X11/Xft stack. `dtksh` is disabled to
  drop the tcl/ksh toolchain requirement.
- **Xsession** is a ksh(93)-syntax script → run by target **mksh**.
- **ToolTalk** (`ttsession`) runs standalone for a local session; no rpcbind.

## RAM economics

- Kernel: ~6-8 MB; base userspace: ~4-6 MB.
- Xorg + neomagic: ~8-12 MB; CDE session: ~12-18 MB.
- Everything is measured in `docs/MEMORY.md` / `docs/BENCHMARKS.md`.
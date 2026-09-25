# Physical deployment — ThinkPad 600X

The supported physical deployment starts with the hybrid live CD/USB ISO built
by `scripts/make-live-iso.sh`. `release/rootfs.ext2` is a filesystem image
only: it has no partition table and no bootloader. Copying it directly to a
disk with `cat` does not produce a bootable disk.

Build the live ISO from the project root after the Buildroot images are in
`release/`:

```sh
./scripts/make-live-iso.sh
```

The script consumes `release/bzImage` and `release/rootfs.tar`. On macOS,
write the resulting `/tmp/thinkpad600x-live.iso` to a USB stick:

```sh
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=/tmp/thinkpad600x-live.iso of=/dev/rdiskN bs=1m
sudo sync
```

Or burn it to CD:

```sh
hdiutil burn /tmp/thinkpad600x-live.iso -speed 4
```

Replace `/dev/diskN` with the actual USB device. The 600X BIOS has no native
USB boot, so use a USB boot mechanism such as Plop Boot Manager, or use the
CD image. At the isolinux prompt, type `3` and Enter for
`Install to internal HDD (/dev/sda)`. When prompted, type `YES` exactly. This
erases all data on `/dev/sda`.

The installer then:

1. creates an MBR and one bootable partition on `/dev/sda` with `sfdisk`;
2. creates `/dev/sda1` with
   `mkfs.ext4 -F -L THINKPAD600X_LIV -O ^metadata_csum,^orphan_file,^64bit`;
3. copies the live root tree and writes `extlinux.conf` and `syslinux.cfg`;
4. copies the COM32 modules, installs extlinux, and writes the syslinux MBR; and
5. reboots into the installed HDD.

The ext4 feature exclusions are required because extlinux 6.03 cannot read a
directory on a filesystem with `metadata_csum` or `orphan_file`; `64bit` is
also disabled. The Buildroot-generated `rootfs.ext2` applies the same feature
set through `BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS`.

After the reboot, the installed system uses `/dev/sda1` and extlinux. The
`console=` order matters: the last `console=` becomes `/dev/console`, so the
working order is `console=ttyS0,115200 console=tty0` (`tty0` last).

`tty1` runs `/usr/sbin/autostart-cde`, not a getty. It calls
`/usr/bin/startx`, which runs `/root/.xinitrc`; `.xinitrc` starts `dtwm` and
then execs `/usr/dt/bin/Xsession`, which starts `ttsession` and `dtsession`.
When CDE exits, the console falls back to a root shell. `ttyS0` is a normal
getty. The `root` password is empty: log in as `root` and press Enter. Do not
pass `/usr/dt/bin/Xsession` as a `startx` client; the generated `.xinitrc` owns
the CDE startup sequence.

Hardware-specific notes (see `docs/HARDWARE.md`):
- No native USB boot support on the 600X BIOS.
- The supplied kernel configuration includes the NeoMagic framebuffer
  (`CONFIG_FB_NEOMAGIC`) and VESA fallback (`CONFIG_FB_VESA`). Real-hardware
  NeoMagic validation remains unverified beyond `docs/adr/ADR-004-display-x11.md` and the
  `docs/NEOMAGIC*.md` research.
- The configuration includes PCMCIA/CardBus (`CONFIG_PCMCIA` + `CONFIG_YENTA`)
  and legacy Ethernet modules.
- IrDA is not enabled in the supplied kernel configuration.

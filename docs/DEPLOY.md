# Physical deployment — ThinkPad 600X

The 600X boots from PATA IDE (not USB). The image is a raw `ext2` filesystem
(`images/rootfs.ext2`). To write it to a physical PATA HDD:

```sh
# Raw copy (fastest — treat the HDD as /dev/sdX):
cat images/rootfs.ext2 > /dev/sdX    # the ext2 IS the full disk
# OR, if the disk needs a bootloader + partition table:
# 1. Create MBR partition (type 83 Linux, start at 2048 sectors, size = image size + 4 MiB bootloader).
# 2. Install syslinux MBR (syslinux /dev/sdX) and add syslinux.cfg pointing to /bzImage.
# 3. Write rootfs.ext2 into the partition (/dev/sdX1).
```

A reproducible bootable-disk image profile can be added via `BR2_IMAGE_BOOT_SCR`
or `post-image.sh`. The project includes a scaffold `post-image.sh` that creates
`/usr/dt` links and fixes permissions; it can be extended to run `syslinux`
+ `cat rootfs.ext2 > /dev/sdX` for deployment automation.

The `board/thinkpad600x/syslinux.cfg` (optional future) points to the kernel
(`bzImage`) and appends `root=/dev/sda rw console=tty1`. The current profile
uses direct kernel boot (`bzImage` + `rootfs.ext2`) for QEMU; the MBR/syslinux
layer is optional but documented.

Hardware-specific notes (see `docs/HARDWARE.md`):
- No USB boot support on 600X BIOS.
- The NeoMagic framebuffer (`CONFIG_FB_NEOMAGIC`) binds to the internal display
  (`1024x768`); `CONFIG_FB_VESA` provides QEMU/fallback graphics.
- PCMCIA/CardBus (`CONFIG_PCMCIA` + `CONFIG_YENTA`) supports Xircom/3Com
  Ethernet adapters for legacy network testing.
- IrDA (`CONFIG_IRDA`) was removed upstream in Linux 4.17; not supported.

To test on real hardware:
1. Write `bzImage` + `rootfs.ext2` to PATA IDE HDD (CF adapter or original 12 GB HDD).
2. Verify `syslinux` MBR or direct boot loader (`LILO` with `-s` / `lilo.conf` pointing to `bzImage`).
3. Boot; console login: `root` / `thinkpad600x`; change password immediately (`passwd`).
4. Start X: `startx /usr/dt/bin/Xsession` (CDE).
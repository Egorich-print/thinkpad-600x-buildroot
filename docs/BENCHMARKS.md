# Benchmarks

Earlier measurements were taken in QEMU (`qemu-system-i386`, `-cpu pentium3`,
`-m 64M`, TCG emulation).
Physical 600X results will be faster for bootloader/kernel init (no TCG overhead)
but slower for mechanical disk reads.

**Evidence caveat:** the repository tracks no boot log at all (`release/*.log`
is git-ignored; only `release/SHA256SUMS.txt` is committed). Local captures (for
example `release/qemu-boot.log`) carry no timestamps, so none
of the timing values below can be derived from them; they also come from a Linux
6.18.7 image (pre-6.12) and record `udhcpc: no lease`. Treat every timing as
**unverified** until re-measured.

## Timing

| Event                  | QEMU (TCG) | Notes |
|------------------------|-----------|-------|
| Kernel init           | ~2 s      | `Freeing initmem` |
| Rootfs mount (`EXT4`) | ~1 s      | `EXT4-fs (sda): mounted` |
| BusyBox `rcS`         | ~4 s      | `syslogd`, `klogd`, `mdev`, `crond` |
| `dropbear` start      | ~2 s      | SSH server |
| Login prompt (getty)  | ~15–25 s  | On `ttyS0`; the log shows `udhcpc: no lease`, not a DHCP lease |
| Full console idle     | ~25 s     | After the getty on `ttyS0` (tty1 auto-starts CDE) |
| Kernel image (`bzImage`) | ≈3.9 MB | `linux-6.12.104` in the current `release/bzImage` |
| Root filesystem image (`rootfs.ext2`) | 512 MiB | Fixed-size image; used-tree size not reproducible from the repository |
| Rootfs tar (`rootfs.tar`) | ≈270 MiB (~283 MB) | Current `release/` artifact |

## Size audit (rootfs contributions, approximate)

| Component             | Installed size (approx) |
|-----------------------|------------------------|
| Kernel + modules      | ~5 MB (`bzImage`) |
| glibc + libtirpc      | ~15 MB (historical estimate) |
| BusyBox userspace     | ~2 MB |
| Core network (iproute2, iputils, dropbear) | ~4 MB |
| Filesystems (e2fsprogs, tmpfs) | ~2 MB |
| Fonts (X11 misc/75/100dpi) | ~8 MB |
| OpenMotif + X11 libs  | ~20 MB (historical estimate) |

These per-component figures are historical estimates from a minimal-image audit
and are not reproducible from the repository. The current full workstation
profile (CDE + apps + browser + office + PDF) ships as `release/rootfs.tar`
≈270 MiB (~283 MB) in `release/` (checksums in `release/SHA256SUMS.txt`), and
the root image is a fixed 512 MiB (`BR2_TARGET_ROOTFS_EXT2_SIZE="512M"`).

## CPU / memory profile (after boot)

Measured via `/proc/meminfo` and `free -m` (QEMU 64 MB):
- **Kernel**: `release/bzImage` ≈3.9 MB compressed; resident kernel + modules
  ~4–6 MB (estimate from the old image, not re-measured).
- **Base userspace (console idle)**: 8 MB used / 30 MB free (after boot + SSH)
  — from the old smoke-test transcript, not preserved in the repository.
- **X11 idle (predicted)**: +10–15 MB (Xorg + neomagic framebuffer + core fonts).
- **CDE session idle (predicted)**: 25–35 MB total used; leaves ~20–30 MB for
  applications / swap / page cache.
- **Swap target**: not enabled in the current rootfs (no swap in `fstab`/the
  defconfig); a `swap` file or `zram` profile is an option for browser /
  office work. Without swap, Dillo (~15–25 MB RSS) and MuPDF (~20–40 MB)
  will push near the 64 MB limit quickly (estimates, unmeasured).

## Size contributors (historical top-level estimates)

- `glibc` (largest single component): ~15 MB installed.
- `openmotif` + `xlib_*`: ~20 MB.
- `linux-headers` (build-time, not in rootfs): ~5–8 MB.
- `base-filesystem`: busybox + skeleton + init scripts: ~2 MB.
- `dropbear`: <1 MB.
- `python3` (host only, not target): not in image.

The per-package figures above are historical estimates and are not reproducible
from the repository; the shipped package set is the one in
`configs/thinkpad600x_defconfig` (no NEdit/Ted/NetSurf/Tailscale in the image).
There are no separate retro/practical configurations in this tree. Those
historical labels describe package groupings, not current profiles; the
`thinkpad600x_defconfig` above is the only current profile.

## Verification commands (reproducible)

```sh
# Memory profile
free -m
cat /proc/meminfo
cat /proc/slabinfo  # kernel slab (if available)
ps -o pid,rss,vsz,comm | sort -k3 -nr | head -20  # RSS list (approximate)

# Rootfs size
find $HOME/br2-out/target/usr/lib -maxdepth 1 -type f -name '*.so*' | wc -l
du -sh $HOME/br2-out/target/usr/lib/*  # library footprint

# Dependency audit
find $HOME/br2-out/target/usr/lib -maxdepth 1 -type f | wc -l  # shared libraries
find $HOME/br2-out/target/usr/bin -type f | wc -l           # installed executables
```

No benchmark script is checked in (`benchmarks/` does not exist); the commands
above plus `scripts/qemu_test.sh` are the only reproducibility aids. The QEMU
smoke-test log (`release/qemu-smoke.log` per `scripts/qemu_test.sh`) is
git-ignored and not part of the repository.
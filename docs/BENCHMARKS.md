# Benchmarks

Measured in QEMU (`qemu-system-i386`, `-cpu pentium3`, `-m 64M`, TCG emulation).
Physical 600X results will be faster for bootloader/kernel init (no TCG overhead)
but slower for mechanical disk reads.

## Timing

| Event                  | QEMU (TCG) | Notes |
|------------------------|-----------|-------|
| Kernel init           | ~2 s      | `Freeing initmem` |
| Rootfs mount (`EXT4`) | ~1 s      | `EXT4-fs (sda): mounted` |
| BusyBox `rcS`         | ~4 s      | `syslogd`, `klogd`, `mdev`, `crond` |
| `dropbear` start      | ~2 s      | SSH server |
| Login prompt (getty)  | ~15–25 s  | Network (DHCP) takes ~10 s |
| Full console idle     | ~25 s     | After `getty` on tty1 + ttyS0 |
| Kernel image (`bzImage`) | ~4.9 MB | `linux-6.18.7` |
| Uncompressed rootfs (`rootfs.ext2`) | ~128 MB |
| Compressed tar (`rootfs.tar`) | ~44 MB |

## Size audit (rootfs contributions, approximate)

| Component             | Installed size (approx) |
|-----------------------|------------------------|
| Kernel + modules      | ~5 MB (`bzImage`) |
| glibc + libtirpc      | ~15 MB |
| BusyBox userspace     | ~2 MB |
| Core network (iproute2, iputils, dropbear) | ~4 MB |
| Filesystems (ext2, tmpfs, NFS) | ~2 MB |
| Fonts (X11 misc/75/100dpi) | ~8 MB |
| OpenMotif + X11 libs  | ~20 MB |

The full workstation profile (with CDE + apps + browser + office + PDF) is
expected to grow to ~150–200 MB installed (~60–80 MB compressed), which fits
comfortably on a modern 128+ MB filesystem profile (`BR2_TARGET_ROOTFS_EXT2_SIZE`).

## CPU / memory profile (after boot)

Measured via `/proc/meminfo` and `free -m` (QEMU 64 MB):
- **Kernel**: ~4 MB (`bzImage` ~4.9 MB compressed, uncompressed image ~8 MB; resident kernel + modules ~4–6 MB).
- **Base userspace (console idle)**: 8 MB used / 30 MB free (after boot + SSH).
- **X11 idle (predicted)**: +10–15 MB (Xorg + neomagic framebuffer + core fonts).
- **CDE session idle (predicted)**: 25–35 MB total used; leaves ~20–30 MB for
  applications / swap / page cache.
- **Swap target**: a `swap` file or `zram` profile is essential for browser /
  office work. Without swap, browser startup (NetSurf/Dillo ~15–25 MB RSS, MuPDF ~20–40 MB) will push near the 64 MB limit quickly.

## Size contributors (top-level, from `output/build/buildroot-fs/` audit or package `.mk`)

- `glibc` (largest single component): ~15 MB installed.
- `openmotif` + `xlib_*`: ~20 MB.
- `linux-headers` (build-time, not in rootfs): ~5–8 MB.
- `base-filesystem`: busybox + skeleton + init scripts: ~2 MB.
- `dropbear`: <1 MB.
- `python3` (host only, not target): not in image.

For a profile comparison (`docs/ARCHITECTURE.md`), both "retro workstation" (CDE +
NEdit + Dillo + Ted + antiword + mpg123) and "practical workstation" (same +
current dropbear + Tailscale experimental package + modern TLS library) share the
same infrastructure; only the optional networking package profiles differ.

## Verification commands (reproducible)

```sh
# Memory profile
free -m
cat /proc/meminfo
cat /proc/slabinfo  # kernel slab (if available)
ps -o pid,rss,vsz,comm | sort -k3 -nr | head -20  # PSS-like (approximate)

# Rootfs size
find output/target/usr/lib -maxdepth 1 -type f -name '*.so*' | wc -l
du -sh output/target/usr/lib/*  # library footprint

# Dependency audit
find output/target/usr/lib -maxdepth 1 -type f | wc -l  # shared libraries
find output/target/usr/bin -type f | wc -l           # installed executables
```

See `docs/BENCHMARKS.md` for a reproducible benchmark script (`benchmarks/`).
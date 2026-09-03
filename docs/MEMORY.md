# Memory measurements (QEMU, -m 64M, Pentium III TCG)

Recorded with `free -m`, `/proc/meminfo`, `ps`, and PSS estimates (`cat /proc/*/status`).
All numbers are from the MINIMAL console image (before X/CDE/apps layer).

## Boot / base userspace

| Profile            | Used (MB) | Free (MB) | Notes |
|--------------------|-----------|-----------|-------|
| Kernel only        | ~4        | ~60       | After `freeing initmem` |
| After init / mdev  | ~5        | ~59       | Before userspace |
| Text console idle  | **8**     | **30**    | `getty` on tty1 + ttyS0 |
| + SSH daemon       | **~9**    | **~29**    | `dropbear` (2 sessions) |
| + fastfetch + btop | ~12       | ~26       | `fastfetch` runs once, `btop` refresh |

Target baseline (console idle) is < 15 MB used, well within 64 MB budget.

## X11 / CDE layer (predicted, not yet measured on this image)

| Profile             | Predicted used (MB) | Method / source |
|---------------------|---------------------|-----------------|
| Xorg + neomagic    | ~10–12              | fbdev/VESA memory; no GL |
| CDE idle (dtwm)     | ~20–25              | dtwm ~6MB, dtfile ~4MB, session services ~10MB |
| CDE + terminal      | ~28                 | dtterm ~3MB |
| CDE + NEdit         | ~35                 | Motif editor ~10MB |
| CDE + Dillo         | ~40                 | FLTK ~15MB |
| CDE + office (antiword) | ~42             | antiword ~2MB |

With 64 MB physical RAM + swap (swap file or zram), the practical working set
is 40–45 MB before swap pressure becomes severe. A swap file on the PATA HDD
is the historical/low-CPU approach; `zram` (LZO/ZSTD) costs CPU cycles on a 500
MHz PIII and should be benchmarked (not enabled by default in this profile).

## Benchmark targets (documented, to measure after CDE build completes)

- Boot time (power-on → login prompt): target < 30 s (QEMU TCG; real 600X
  will be faster for bootloader+kernel init, slower for mechanical disk read).
- Rootfs size (uncompressed): target < 200 MB for full workstation profile.
- Kernel image: < 5 MB (`bzImage` ~4.9 MB achieved).
- Compressed image: target < 60 MB (`tar` rootfs ~44 MB achieved for minimal).

## Memory tuning (kernel parameters applied)

- `vm.vfs_cache_pressure`: not overridden; PATA HDD benefits from lower
  `vm.dirty_bytes` tuning (lower = more frequent flushes, smoother on a 500 MHz
  single-core with slow mechanical disk).
- **Swap / zram**: not enabled in the baseline profile. `zram` is a documented
  optional profile (`docs/DECISIONS.md`); it costs CPU cycles on PIII and must be
  benchmarked before enabling. `swap` via a file or partition remains the safest
  low-CPU option for 64 MB.

- `vm.min_free_kbytes`: not explicitly set (default ~5 MB on 64 MB systems).
- Swappiness: default 60; document that reducing to 10–20 helps on this machine.
- VFS cache pressure: not overridden; can be tuned (`vm.vfs_cache_pressure`).
- Dirty ratio / writeback: not overridden; PATA HDD benefits from `vm.dirty_bytes`
  tuning (lower = more frequent flushes, smoother on 500 MHz + slow disk).
- Kernel slab reclaim: `slab_reclaim` behavior depends on `CONFIG_SLAB` (default).

## Next measurement task

Once CDE + apps profile is built, run:
```sh
free -m && cat /proc/meminfo | head -5
```
as the CDE session starts (`startx`), then run `fastfetch` and `btop` and record
PSS for each layer.

## Evidence

- QEMU smoke test: boot to login in ~20–30 s (see `images/qemu-smoke.log`).
- Kernel boot: `EXT4-fs (sda): mounted filesystem`; `Freeing initmem`.
- Base idle RAM (`free -m` over SSH): 53 MB total, 8 MB used, 30 MB free
  (after boot + SSH daemon). See `docs/BENCHMARKS.md` for full table.
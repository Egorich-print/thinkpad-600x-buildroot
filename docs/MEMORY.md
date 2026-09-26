# Memory measurements (QEMU, -m 64M, Pentium III TCG)

Recorded with `free -m`, `/proc/meminfo`, `ps`, and PSS estimates (`cat /proc/*/status`).
All numbers are from the MINIMAL console image (before X/CDE/apps layer), i.e.
they predate the current CDE release. The `free -m`/PSS captures are **not
reproducible from the repository**: it tracks no logs (`release/*.log` is
git-ignored) and the old `images/` directory with the smoke-test log is gone.

## Boot / base userspace

| Profile            | Used (MB) | Free (MB) | Notes |
|--------------------|-----------|-----------|-------|
| Kernel only        | ~4        | ~60       | After `freeing initmem` |
| After init / mdev  | ~5        | ~59       | Before userspace |
| Text console idle  | **8**     | **30**    | `getty` on ttyS0; on the current image tty1 auto-starts CDE (`autostart-cde`) |
| + SSH daemon       | **~9**    | **~29**    | `dropbear` (2 sessions) |
| + fastfetch + btop | ~12       | ~26       | `fastfetch` runs once, `btop` refresh |

Target baseline (console idle) is < 15 MB used, well within 64 MB budget.

## X11 / CDE layer (predicted, not yet measured on this image)

| Profile             | Predicted used (MB) | Method / source |
|---------------------|---------------------|-----------------|
| Xorg + neomagic    | ~10–12              | fbdev/VESA memory; no GL |
| CDE idle (dtwm)     | ~20–25              | dtwm ~6MB, dtfile ~4MB, session services ~10MB |
| CDE + terminal      | ~28                 | dtterm ~3MB |
| CDE + dtpad         | ~35                 | CDE Motif editor ~10MB |
| CDE + Dillo         | ~40                 | FLTK ~15MB |
| CDE + office (antiword) | ~42             | antiword ~2MB |

With 64 MB physical RAM + swap (swap file or zram), the practical working set
is 40–45 MB before swap pressure becomes severe. A swap file on the PATA HDD
is the historical/low-CPU approach; `zram` (LZO/ZSTD) costs CPU cycles on a 500
MHz PIII and should be benchmarked (not enabled by default in this profile).

## Benchmark targets (documented, not yet measured on the current CDE image)

- Boot time (power-on → login prompt): target < 30 s (QEMU TCG; real 600X
  will be faster for bootloader+kernel init, slower for mechanical disk read).
  In the current image tty1 auto-starts CDE; the login prompt is on ttyS0.
- Rootfs size (uncompressed): target < 200 MB for full workstation profile.
- Kernel image: < 5 MB (`release/bzImage` ≈3.7 MiB in the current release).
- Rootfs tar archive: target < 60 MB for the minimal profile. The current full
  release ships `release/rootfs.tar` ≈253 MiB (see `release/` and
  `release/SHA256SUMS.txt`); the target was met only by the minimal profile.

## Memory tuning (kernel parameters applied)

- `vm.vfs_cache_pressure`: not overridden; PATA HDD benefits from lower
  `vm.dirty_bytes` tuning (lower = more frequent flushes, smoother on a 500 MHz
  single-core with slow mechanical disk).
- **Swap / zram**: not enabled in the baseline profile. `zram` is an optional idea,
  not a configured profile; it costs CPU cycles on PIII and must be benchmarked
  before enabling. `swap` via a file or partition remains the safest low-CPU
  option for 64 MB.

- `vm.min_free_kbytes`: not explicitly set (default ~5 MB on 64 MB systems).
- Swappiness: default 60; document that reducing to 10–20 helps on this machine.
- VFS cache pressure: not overridden; can be tuned (`vm.vfs_cache_pressure`).
- Dirty ratio / writeback: not overridden; PATA HDD benefits from `vm.dirty_bytes`
  tuning (lower = more frequent flushes, smoother on 500 MHz + slow disk).
- Kernel slab reclaim: `slab_reclaim` behavior depends on `CONFIG_SLAB` (default).

## Next measurement task

To measure the current CDE + apps profile, run:
```sh
free -m && cat /proc/meminfo | head -5
```
as the CDE session starts (`startx`), then run `fastfetch` and `btop` and record
PSS for each layer.

## Evidence

- QEMU smoke test: boot to login in ~20–30 s — **not reproducible from the
  repository**; the cited `images/qemu-smoke.log` was deleted with `images/`
  (`scripts/qemu_test.sh` now writes the git-ignored `release/qemu-smoke.log`).
  No surviving capture has timestamps, so login time cannot be derived.
- Kernel boot: `EXT4-fs (sda): mounted filesystem`; `Freeing initmem` — seen
  only in a local, git-ignored capture from a Linux 6.18.7 image (pre-6.12).
- Base idle RAM (`free -m` over SSH): 53 MB total, 8 MB used, 30 MB free
  (after boot + SSH daemon) — from the old smoke-test transcript, not preserved
  in the repository. See `docs/BENCHMARKS.md` for the same table and its
  caveats.
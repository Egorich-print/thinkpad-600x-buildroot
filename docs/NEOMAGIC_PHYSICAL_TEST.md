# NeoMagic — physical ThinkPad 600X test & benchmark plan

## Hardware under test

IBM ThinkPad 600X 2645-4EU, NeoMagic MagicGraph 256ZX (NM2360), 4 MB VRAM,
Pentium III 500 MHz, 64 MB RAM, LCD native 1024×768 (16 bpp target).

## `neomagic_diag` runbook (must be reversible/safe)

```
neomagic_diag                 # print device id, VRAM, fb/MMIO, current mode, accel status
neomagic_diag --test-fill     # solid fill 640x480 rect, HW, pixel check + time
neomagic_diag --test-blit     # 800x600 copy + overlap-down copy, compare + time
neomagic_diag --test-rop      # copy vs xor, verify distinct results
neomagic_diag --dry-run       # safe: print identity/BLT status, write nothing
```

Rules:
- No blind MMIO probing; only the documented BLT block (`NEOMAGIC_REGISTER_MAP.md`).
- Each test waits for the engine to become idle and re-initializes the
  non-triggering depth/pitch state on normal exit; a failed op reports and exits
  non-zero. It does not save or rewrite raw write-only registers.
- `wait_idle` is time-bounded; on timeout the engine is re-inited and the test aborts.

## Benchmark matrix (fill with **measured** values only)

| Operation | Software µs | Hardware µs | CPU % | Speedup |
|-----------|-----------:|-----------:|------:|--------:|
| Fill 1000×1000 (16 bpp) | | | | |
| Fill 1000×1000 (8 bpp) | | | | |
| Copy 800×600 | | | | |
| Copy 100×100 | | | | |
| Copy 640×480 (window) | | | | |
| Scroll (terminal, 80×24) | | | | |

Method: `clock_gettime(CLOCK_MONOTONIC)` around the op; CPU% via `/proc/self/stat`
(utime+stime) difference over the batch; repeat N to stabilize; report median.

## Realistic GUI check

CDE → dtterm (scroll, select), dtfile (open dir, scroll), window move/resize, menu
redraw, image open (feh). Observe: corruption, tearing, freezes, CPU load (btop),
responsiveness. Compare software vs accelerated image.

## Success criteria

- `--test-fill` and `--test-blit` pass → fill/blit paths confirmed (LEVEL 2/3).
- CDE window move/scroll visibly smoother **and** lower Pentium III CPU% under btop
  (LEVEL 5).
- 64 MB boot with accelerated image; no corruption/freeze (LEVEL 6 candidate).
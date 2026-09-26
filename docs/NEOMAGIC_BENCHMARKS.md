# NeoMagic — benchmarks (design + results placeholder)

> Only measured values belong here. Until the physical 600X runs `neomagic_diag`
> (exists: `tools/neomagic_diag`) and `neomagic-bench` (**planned, not written
> yet — no such file exists, `tools/` holds only `aquarium` and
> `neomagic_diag`**), the table below is intentionally empty. The numbers stay
> empty until the tool exists and has been run on real hardware.

## What to measure and why

The goal is **Pentium III CPU drain reduction**, not peak GPU throughput. A hardware
path that is only marginally faster per-pixel but frees the CPU (async BLT while the
CPU does other work) is still valuable. So report both latency and CPU%.

## Microbenchmarks (per op, per depth 8/16 bpp)

- Fill 1000×1000
- Copy 800×600, 100×100, 640×480 (window-sized)
- Mono imageblit (font blit) 8×16 repeated — the CDE-critical op
- Scroll (screen-to-screen Y-copy)

## Results

| Operation | Software µs | Hardware µs | CPU % | Speedup |
|-----------|-----------:|-----------:|------:|--------:|
| Fill 1000×1000 | | | | |
| Copy 800×600 | | | | |
| Copy 100×100 | | | | |
| Scroll | | | | |

## Methodology notes

- `clock_gettime(CLOCK_MONOTONIC)`; CPU% from `/proc/self/stat` delta; N=100 median.
- Hardware path: mmap BAR0/BAR1, program BLT, `wait_idle(timeout)`.
- Software path: `memcpy`/`memset` to the mapped framebuffer (exact equivalent).
- Compare on the **same** physical machine, same mode, same depth.
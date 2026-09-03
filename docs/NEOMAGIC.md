# NeoMagic MagicGraph 256ZX — 2D hardware acceleration: findings

## Primary research question

> Does the NeoMagic MagicGraph 256ZX (NM2360) contain a usable 2D command engine?

**Answer: YES — definitively, with HIGH confidence.** The chip has a BitBLT engine
providing **solid fill, screen-to-screen bitblt, host-to-video mono-image expansion
(i.e. accelerated text/glyph rendering), ROP (copy/xor), clipping, direction-based
overlap handling, and a hardware cursor**. This is not reverse-engineered guesswork:
it is the **live, in-tree code of the Linux 6.18 LTS kernel**:

- `drivers/video/fbdev/neofb.c` declares, for the NM2360 (`0x10c8:0x0006`):
  ```c
  info->flags |= FBINFO_HWACCEL_IMAGEBLIT |
                 FBINFO_HWACCEL_COPYAREA | FBINFO_HWACCEL_FILLRECT;
  ```
  and programs the engine directly in `neo2200_accel_init` / `neo2200_fillrect` /
  `neo2200_copyarea` / `neo2200_imageblit`.
- The register map and bit fields are in `include/video/neomagic.h`, mirrored by the
  X.Org driver `xf86-video-neomagic` (`neo_reg.h`, `neo_2200.c`).

So the earlier claim "hardware acceleration is not available / shadowfb only" was
**wrong**, and is now corrected in `X11.md` and `DECISIONS.md`. The true situation:

| Layer | Acceleration status |
|-------|---------------------|
| Linux console (fbcon) | **Already hardware-accelerated** via `neofb` (fonts use imageblit; scroll uses copyarea) |
| X11/CDE (Xorg `neomagic`/`fbdev` DDX) | **Software** (shadowfb) — the *gap to close* |
| Hardware | Capable (BitBLT engine live in kernel) |

## Why the "no acceleration" conclusion happened

XAA (the XFree86 `software acceleration architecture`) was removed from xorg-server in
1.13 (2012). That removed the *X11-side backend* that historically drove this same BLT
engine. It did **not** remove the hardware capability — the kernel kept its own
accelerator path all along. The gap is a *driver* gap (X11 → BLT registers), not a
*hardware* gap.

## What is needed to reach CDE acceleration

Closed loop, lowest-risk first — full analysis in `NEOMAGIC_ACCELERATION.md`:

1. **Standalone proof** (`tools/neomagic_diag`): mmap BAR0 (fb) + BAR1 (MMIO), replicate
   `neofb.c` sequences, verify fill/blit/ROP on the **physical 600X**. → LEVEL 2/3.
2. **X11 integration**: add an **EXA backend** to `xf86-video-neomagic` (EXA still ships
   in xorg-server 21.x) that programs the same registers for `Solid` + `Copy`. EXA
   pixmaps in VRAM are the only hard requirement. → LEVEL 4.
3. **Optional restoration of XAA**: bigger, but benefits ~30 legacy chips ("not only
   NeoMagic uses XAA") — the GitHub-publish request from the community. → see below.

## Level classification

| Level | Status | Evidence |
|-------|:------:|----------|
| 0 — engine found | ✅ DONE | BitBLT engine confirmed in kernel source |
| 1 — register map recovered | ✅ DONE (HIGH) | `NEOMAGIC_REGISTER_MAP.md` |
| 2 — standalone fill works | ⏳ code written, **needs physical 600X** | `neomagic_diag --test-fill` |
| 3 — hardware blit works | ⏳ code written, **needs physical 600X** | `neomagic_diag --test-blit` |
| 4 — X11 uses fill/blit | ⏳ EXA backend (next workstream) | — |
| 5 — CDE benefits measurably | ⏳ blocked on L4 + hardware | benches in `NEOMAGIC_BENCHMARKS.md` |
| 6 — physical 600X validated | ⏳ blocked on hardware | `NEOMAGIC_PHYSICAL_TEST.md` |

## Honest boundaries

- **No public datasheet exists** (NeoMagic never released one; verified) — but the
  register spec is *fully* public via the GPL driver source, which counts as high
  confidence because it is working code, not speculation.
- **No emulator models NeoMagic** (QEMU/86Box/PCem/DOSBox-X: verified none). So the
  accelerator can only be **functionally validated on the physical 600X**. QEMU remains
  for software/modesetting integration only.
- The two registers named-but-unused (`xpColor`, the `FILL_PAT`/line-draw cases) are
  **LOW/MEDIUM** confidence and must not be driven without an experiment.
- The kernel busy-wait has **no timeout**. Any new driver must add one (recovery, §
  `NEOMAGIC_ACCELERATION.md`).

## Final statement (mission-standard)

R**eal hardware exists → real register programming is recovered (GPL, working) → real
acceleration is achievable → the CPU saving is measurable** — but the *demonstration*
requires the physical ThinkPad 600X, because no emulator reproduces the NeoMagic BLT
engine.
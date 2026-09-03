# NeoMagic — historical sources, XAA, and licenses

## Primary register/programming sources (all public, all GPL)

| Artifact | Where | What it gives |
|----------|-------|---------------|
| `drivers/video/fbdev/neofb.c` | Linux (in-tree, incl. 6.18 LTS) | **Working accel code**: `neo2200_accel_init/fillrect/copyarea/imageblit/sync`; chip→VRAM/clock table; MMIO BAR mapping |
| `include/video/neomagic.h` | Linux (in-tree) | `struct Neo2200` register layout + all `NEO_BC0/1/2/3`, `NEO_MODE1_*`, `NEO_BS0_*`, cursor regs, PCI IDs |
| `xf86-video-neomagic` (`neo_reg.h`, `neo_2200.c`, `neo_2090.c`, `neomagic_accel.c`) | freedesktop xorg (`xf86-video-neomagic`); mirrors: github `freedesktop-unofficial-mirror/xorg__driver__xf86-video-neomagic`, `X11Libre/xf86-video-neomagic` | The **XAA acceleration backend** (historical); independent confirmation of the same registers |
| `sound/pci/nm256/nm256.c` | Linux (in-tree) | Audio side (NM256ZX audio `0x8006`), not needed for BLT |

## XAA history

- XAA (XFree86 Acceleration Architecture) was the generic software acceleration
  interface shared by ~30 drivers (neomagic, s3/s3virge, tdfx, trident, sis, i810,
  siliconmotion, chips, …). It standardized the hooks: `SetupFor*/Subsequent*/Sync/Wait`
  for `ScreenToScreenCopy`, `SolidFill`, `SolidLine`, `Mono8x8PatternFill`, `ImageWrite`,
  `CPUToScreenColorExpandFill`, etc. — mapped to each chip's own BLT registers.
- **XAA removed from xorg-server in 1.13 (2012).** The per-chip drivers (including
  neomagic) dropped their XAA block and fell back to shadowfb.
- The neomagic driver's historical XAA code still exists in its git history
  (tags `neomagic-1_1_0` … final releases through ~1.2.x carry the full XAA accel;
  the removal commit logs "Fall back to shadowfb when XAA unavailable" (2011) /
  "Don't call NEO_Sync with no XAA" (2012)).

### neomagic XAA hook → register mapping (reconstructed)

| XAA hook | NeoMagic registers | neofb.c equivalent |
|----------|--------------------|--------------------|
| `SetupForSolidFill`/`SubsequentSolidFill` | `bltCntl` = FIFO_EN\|SRC_IS_FG\|SKIP_MAPPING\|ROP; `fgColor`; `dstStart`; `xyExt` | `neo2200_fillrect` |
| `SetupForScreenToScreenCopy`/`Subsequent…` | `bltCntl` (+ dec bits on overlap); `srcStart`; `dstStart`; `xyExt` | `neo2200_copyarea` |
| `SetupForImageWrite`/`Subsequent…` (mono) | `bltCntl` = SYS_TO_VID\|SRC_MONO; `fgColor`/`bgColor`; `dstStart`; `xyExt`; data → staging | `neo2200_imageblit` |
| `Sync` | poll `bltStat & 1` | `neo2200_sync` |
| `NeoAccelInit`/`ScreenInit` | `bltStat` = bltMod<<16; `pitch` | `neo2200_accel_init` |

## Patents (context; none document the BLT register block itself)

- **US5703806A** — "Graphics controller integrated circuit without memory interface"
  (NeoMagic, Deepraj Puar). The unified-memory (graphics+DRAM on one die) foundation.
- **US6016151A**, **US6222550B1** — 3D/texture engine (later MagicMedia), not the 2D BLT.
- **US5757338A** (EMI), **US5615376A** (clock/power), **USRE43235E1** / **USRE43565E1**
  (post-NeoMagic reassigned, framebuffer/refresh arbitration).

## License audit (before copying any code)

- `neofb.c` / `neomagic.h` — **GPL-2.0**, fine to study and to write a *new* driver from
  (never cut-paste GPL register lists into a non-GPL kernel module; the kernel driver
  and Xorg DDX are both GPL-compatible contexts here).
- `xf86-video-neomagic` — **MIT ("X11") license** (standard xorg), compatible with Xorg.
- The recovered register *bytes/offsets* are "facts" (not copyrightable expression);
  the safe practice is to write a clean modern implementation and cite the source, not
  reproduce old code verbatim into a differently-licensed component without care.

## Reproducibility / provenance record

- Kernel commit scope: current 6.18 LTS tree (`linux-6.18.7` used here; 6.18 line is
  Longterm through Dec 2028).
- Source of register map in this repo: `docs/NEOMAGIC_REGISTER_MAP.md` cites offsets and
  bit masks from `neomagic.h` + `neofb.c`.
- Historical XAA structure: `xf86-video-neomagic` git history (freedesktop), MIT licensed.
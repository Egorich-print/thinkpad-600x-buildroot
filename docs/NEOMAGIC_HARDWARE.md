# NeoMagic MagicGraph 256ZX (NM2360) — Hardware

## Identity / PCI

| Field | Value | Source |
|-------|-------|--------|
| Vendor | `0x10c8` NeoMagic Corporation | `pci_ids.h` `PCI_VENDOR_ID_NEOMAGIC` |
| Device (video) | `0x0006` MagicGraph 256ZX | `neomagic.h` `PCI_CHIP_NM2360` |
| Device (audio, companion) | `0x8006` NM256ZX Audio | `pci_ids.h` `PCI_DEVICE_ID_NEOMAGIC_NM256ZX_AUDIO` |
| Device class | VGA compatible (`0x030000`) | standard |
| Subsystem | vendor/board specific (to read on real 600X) | probe |

Full chip ID table (from `include/video/neomagic.h`):

| Chip | Device ID | Marketing name |
|------|----------:|----------------|
| NM2070 | `0x0001` | MagicGraph 128 (ZV) |
| NM2090 | `0x0002` | MagicGraph 128V |
| NM2093 | `0x0003` | MagicGraph 128ZV+ |
| NM2097 | `0x0083` | MagicGraph 128ZV+ (alt) |
| NM2160 | `0x0004` | MagicGraph 128XD |
| NM2200 | `0x0005` | MagicMedia 256AV |
| NM2230 | `0x0025` | MagicMedia 256AV+ |
| **NM2360** | **`0x0006`** | **MagicGraph 256ZX** (this machine) |
| NM2380 | `0x0016` | MagicMedia 256XL+ |

## VRAM

- **Size (NM2360): 4096 KB (4 MB)** — `neofb.c` `neo_init_hw` (`videoRam = 4096`).
- **maxClock: 110 MHz** (`maxClock = 110000` kHz).
- Architected as **unified memory** (graphics logic + DRAM on one die) — see patent
  US5703806A in `NEOMAGIC_HISTORICAL.md`.
- On real hardware the 600X reports 4 MB; the driver treats the value read from the
  chip as authoritative (`read_neo_ram_size`/fixed table).

## Framebuffer / memory layout

- **BAR0** = linear framebuffer (PCI base address register 0).
- **BAR1** = 2 MB MMIO register window (`MMIO_SIZE = 0x200000`) — BLT + cursor live here.
- **Modes:** `8`, `15/16` (packed), `24` bpp. `NEO_MODE1_DEPTH8/16/24`.
- **Pitch** (bytes/row) = `xres_virtual * bpp/8`; programmed into `pitch` register.
- **Modes tested in tree:** 640×480, 800×600, 1024×768 (bios mode table `0x36`/`0x39` etc.).
- **Endian:** driver uses `writel()`/`memcpy_toio()`, so little-endian MMIO on x86 — same
  convention the hardware expects (no byteswap in the kernel accel path).

## MMIO → register blocks

```
BAR1 + 0x00000   BitBLT register block (struct Neo2200, 32 regs)   ← acceleration
BAR1 + 0x00100   Hardware cursor (NEOREG_CUR*)                     ← cursor
BAR1 + 0x100000  Host→video staging buffer (imageblit SYS_TO_VID)
```

Framebuffer (BAR0) and MMIO (BAR1) are separate mappings; the BLT reads/writes the
**framebuffer** via `srcStart`/`dstStart` **byte offsets**, so the natural userspace
model is: `mmap(BAR0)` for pixels, `mmap(BAR1)` for the BLT registers.

## VGA / extended registers

`neofb.c` also programs the normal/extended VGA state (`struct neofb_par`: MiscOutReg,
CRTC[25], Sequencer[5], Graphics[9], Attribute[21], plus `NEO_EXT_CR_MAX=0x85`,
`NEO_EXT_GR_MAX=0xC7`, `GeneralLockReg`, `ExtCRTDispAddr`, `ExtColorModeSelect`, panel
disp/centering regs, VCLK). These are mode-set plumbing, **not** part of the 2D BLT
engine — needed for the DDX/modesetting layer but not for the accelerator itself.

## Hardware capabilities confirmed from GPL sources

| Capability | Present | Evidence |
|-----------|:------:|----------|
| Solid fill | yes | `neo2200_fillrect` + `FBINFO_HWACCEL_FILLRECT` |
| Screen-to-screen BLT | yes | `neo2200_copyarea` + `FBINFO_HWACCEL_COPYAREA` |
| Host→video mono expansion (glyph/text) | yes | `neo2200_imageblit` + `FBINFO_HWACCEL_IMAGEBLIT` |
| ROP (copy / xor) | yes | `0x0C0000` / `0x060000` |
| Directional overlap handling | yes | `BC0_X_DEC/DST_Y_DEC/SRC_Y_DEC` |
| Clipping | yes (registers) | `clipLT`/`clipRB` + `BC3_CLIP_ON` |
| Hardware cursor | yes | `NEOREG_CUR*` registers |
| Line drawing | **not documented** | no register/hook found in kernel or XAA source |
| Pattern fill (8×8/32×32) | **defined, unverified** | `xpColor`/`FILL_PAT` named but unused in `neofb` |

The BitBLT engine is command-**triggered** (a store to `xyExt` starts the op); "FIFO"
deferral exists but the only sync primitive proven reliable is the busy bit
(`bltStat & 1`) with `cpu_relax()` polling.
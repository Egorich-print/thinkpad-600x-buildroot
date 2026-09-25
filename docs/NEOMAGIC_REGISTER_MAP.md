# NeoMagic MagicGraph 256ZX (NM2360) — Register Map

All entries below are **recovered from GPL sources in a historical `linux-6.18.7`
source snapshot**, not invented. The current image kernel is Linux 6.12.104.
Primary sources:

- `include/video/neomagic.h` — register names, offsets (via `struct Neo2200`), bit masks, PCI IDs.
- `drivers/video/fbdev/neofb.c` — the *working* programming sequences
  (`neo2200_accel_init`, `neo2200_fillrect`, `neo2200_copyarea`, `neo2200_imageblit`,
  `neo2200_sync`).
- `xf86-video-neomagic` (`neo_reg.h`, `neo_2200.c`) — independent confirmation (X.Org driver).

**There is no public NeoMagic datasheet** (company never released one; confirmed by
research — see `NEOMAGIC_HISTORICAL.md`). The de-facto "spec" is the GPL driver source.
Confidence reflects how authoritatively an entry is backed by *working code* vs. merely
being *named* in a header.

## Address space

| Region | Location | Size | Notes |
|--------|----------|-----:|-------|
| MMIO (+ BLT + cursor) | PCI BAR1 | `0x200000` (2 MB) | `vidmem`/registers; BLT block at offset 0 |
| BLT register block | BAR1 + `0x00` | 37×4 bytes | `struct Neo2200` (see below) |
| Hardware cursor | BAR1 + `cursorOff` (`0x1000` on NM2200–NM2380) | 6×4 bytes | `NEOREG_CUR*` |
| Host→video staging buffer | BAR1 + `0x100000` | — | `imageblit` writes glyph data here (`SYS_TO_VID`) |
| Framebuffer | BAR0 (linear) | up to 4 MB | see `NEOMAGIC_HARDWARE.md` |

## BitBLT register block (`struct Neo2200`, offsets from BAR1 MMIO base)

| Offset | Name | W | Meaning | Source | Conf |
|-------:|------|:-:|---------|--------|:----:|
| `0x00` | `bltStat` | 32 | Status/control: bit0 = BLT busy (`NEO_BS0_BLT_BUSY`), bit1 = FIFO avail, bit2 = FIFO pend; **bits[8:15] = FIFO free space**; **bits[16:31] = `bltMod`** (depth is written at accel init; width fields are defined in the header) | `neofb.c` sync/accel_init, `neomagic.h` | HIGH |
| `0x04` | `bltCntl` | 32 | BLT command bits BC0/BC1/BC2/BC3 + ROP field (see below) | `neofb.c` fill/copy/imageblit | HIGH |
| `0x08` | `xpColor` | 32 | expand-pattern color (defined; **not written** in current `neofb` accel path) | `neomagic.h` | MEDIUM |
| `0x0C` | `fgColor` | 32 | Foreground / solid-fill / pattern color | `neofb.c` | HIGH |
| `0x10` | `bgColor` | 32 | Background color (mono→color expansion) | `neofb.c` imageblit | HIGH |
| `0x14` | `pitch` | 32 | `(dst_pitch_bytes << 16) | src_pitch_bytes` | `neofb.c` accel_init | HIGH |
| `0x18` | `clipLT` | 32 | Clip window left/top | `neomagic.h` | MEDIUM |
| `0x1C` | `clipRB` | 32 | Clip window right/bottom | `neomagic.h` | MEDIUM |
| `0x20` | `srcBitOffset` | 32 | Source mono bit offset | `neomagic.h` | MEDIUM |
| `0x24` | `srcStart` | 32 | Source **byte** offset into framebuffer | `neofb.c` copyarea | HIGH |
| `0x28` | `reserved0` | 32 | reserved | `neomagic.h` | — |
| `0x2C` | `dstStart` | 32 | Destination **byte** offset into framebuffer | `neofb.c` | HIGH |
| `0x30` | `xyExt` | 32 | `(height << 16) | width`; **writing this register triggers the BLT** | `neofb.c` (always the last write) | HIGH |
| `0x34..0x7C` | `reserved1[19]` | — | reserved | `neomagic.h` | — |
| `0x80` | `pageCntl` | 32 | banked-page control (defined; unused in current accel path) | `neomagic.h` | LOW |
| `0x84` | `pageBase` | 32 | page base | `neomagic.h` | LOW |
| `0x88` | `postBase` | 32 | post base | `neomagic.h` | LOW |
| `0x8C` | `postPtr` | 32 | post pointer | `neomagic.h` | LOW |
| `0x90` | `dataPtr` | 32 | data pointer | `neomagic.h` | LOW |

## `bltCntl` bit fields (HIGH confidence — all from `neomagic.h`)

### BC0 (bits 0–7)
| Bit | Mask | Name | Meaning |
|----:|-----:|------|---------|
| 0 | `0x000001` | `DST_Y_DEC` | destination Y decrement (bottom-up) |
| 1 | `0x000002` | `X_DEC` | X decrement (right-to-left) |
| 2 | `0x000004` | `SRC_TRANS` | source transparent |
| 3 | `0x000008` | `SRC_IS_FG` | source is solid foreground color |
| 4 | `0x000010` | `SRC_Y_DEC` | source Y decrement |
| 5 | `0x000020` | `FILL_PAT` | fill pattern |
| 6 | `0x000040` | `SRC_MONO` | source is 1 bpp (mono→color expansion) |
| 7 | `0x000080` | `SYS_TO_VID` | host/system-memory → video (data via staging buffer) |

### BC1 (bits 8–15)
| Mask | Name | Meaning |
|-----:|------|---------|
| `0x000100` | `DEPTH8` | 8 bpp operation |
| `0x000200` | `DEPTH16` | 15/16 bpp operation |
| `0x000400` | `X_320` | stride width 320 |
| `0x000800` | `X_640` | stride width 640 |
| `0x000C00` | `X_800` | stride width 800 |
| `0x001000` | `X_1024` | stride width 1024 |
| `0x001400` | `X_1152` | stride width 1152 |
| `0x001800` | `X_1280` | stride width 1280 |
| `0x001C00` | `X_1600` | stride width 1600 |
| `0x002000` | `DST_TRANS` | destination transparent |
| `0x004000` | `MSTR_BLT` | master blit |
| `0x008000` | `FILTER_Z` | zero-filter |

### BC2 (bits 16–23)
| Mask | Name | Meaning |
|-----:|------|---------|
| `0x00800000` | `WR_TR_DST` | write-through destination |

> The **ROP field** also sits in bits 16–23. Observed working values from `neofb.c`:
> `0x0C0000` = **copy** (default), `0x060000` = **XOR** (chosen when `rop != 0` in
> `neo2200_fillrect`). Both match the classic VGA/GX raster-op truth table
> (`GXcopy = 0xC`, `GXxor = 0x6`), so the ROP is the standard 4-bit boolean-function
> encoding. Confidence: **HIGH for copy/xor**, MEDIUM for the full 4-bit field width.

### BC3 (bits 24–31)
| Mask | Name | Meaning |
|-----:|------|---------|
| `0x01000000` | `SRC_XY_ADDR` | source addr as X/Y (vs linear) |
| `0x02000000` | `DST_XY_ADDR` | destination addr as X/Y |
| `0x04000000` | `CLIP_ON` | enable clip (uses `clipLT`/`clipRB`) |
| `0x08000000` | `FIFO_EN` | FIFO enabled |
| `0x10000000` | `BLT_ON_ADDR` | trigger BLT on address write |
| `0x80000000` | `SKIP_MAPPING` | skip MMU/bank mapping |

## `bltStat` extended field (written at accel init, HIGH)

`neo2200_accel_init` writes `bltMod << 16` into `bltStat`, where `bltMod` is:

| Mask | Name | Meaning |
|-----:|------|---------|
| `0x0100` | `MODE1_DEPTH8` | 8 bpp |
| `0x0200` | `MODE1_DEPTH16` | 15/16 bpp |
| `0x0300` | `MODE1_DEPTH24` | 24 bpp |
| `0x0400` | `MODE1_X_320` … `0x1C00` `MODE1_X_1600` | stride width |
| `0x2000` | `MODE1_BLT_ON_ADDR` | BLT trigger on address write |

And `pitch` register = `(pitch << 16) | pitch`, where `pitch` =
`xres_virtual * (bpp/8)` (bytes per row), same for src and dst.

## Hardware cursor (BAR1 + `cursorOff`; `cursorOff = 0x100` for NM2070–NM2160 and `0x1000` for NM2200–NM2380)

| Offset | Name | Meaning | Conf |
|-------:|------|---------|:----:|
| `+0x00` | `CURSCNTL` | control: `NEO_CURS_ENABLE=0x01`, `NEO_ICON64_ENABLE=0x08`, `NEO_ICON128_ENABLE=0x0C`, `NEO_ICON_BLANK=0x10` | HIGH |
| `+0x04` | `CURSX` | cursor X position | HIGH |
| `+0x08` | `CURSY` | cursor Y position | HIGH |
| `+0x0C` | `CURSBGCOLOR` | cursor background color | HIGH |
| `+0x10` | `CURSFGCOLOR` | cursor foreground color | HIGH |
| `+0x14` | `CURSMEMPOS` | cursor bitmap memory position | HIGH |

## Synchronization (HIGH)

- **Busy/idle:** `while (readl(bltStat) & 1) cpu_relax();` — bit 0 (`NEO_BS0_BLT_BUSY`).
- **FIFO depth:** `bltStat >> 8` (bits 8+). The in-tree `neo2200_wait_fifo` currently
  just calls `sync()`; the FIFO-space heuristic was disabled upstream
  ("FIXME: does not work"), so `sync()` (wait-until-idle) is the safe, supported path.
- **Timeouts:** the kernel driver does *not* impose a timeout on the busy loop (it relies
  on the engine draining). A new driver MUST add a bounded timeout → reset/fallback
  (see `NEOMAGIC_ACCELERATION.md` § recovery).

## Operation sequence summary (reconstructed from `neofb.c`)

**Init** (once after mode set):
```
write bltStat = (bltMod /* DEPTH8|16|24 */) << 16
write pitch  = (pitch_bytes << 16) | pitch_bytes          ; pitch = xres_virtual * bpp/8
write fgColor/bgColor as needed
```

**Solid fill** (`neo2200_fillrect`):
```
wait_idle()
write bltCntl  = BC3_FIFO_EN | BC0_SRC_IS_FG | BC3_SKIP_MAPPING | ROP
                 (ROP = 0x0C0000 copy, or 0x060000 xor)
write fgColor  = color
write dstStart = (dx + dy*xres_virtual) * bpp/8            ; byte offset
write xyExt    = (height << 16) | width                    ; TRIGGERS
```

**Screen-to-screen BLT** (`neo2200_copyarea`):
```
wait_idle()
bltCntl = BC3_FIFO_EN | BC3_SKIP_MAPPING | 0x0C0000
if overlap (dy>sy || (dy==sy && dx>sx)):                    ; bottom-right first
    bltCntl |= BC0_X_DEC | BC0_DST_Y_DEC | BC0_SRC_Y_DEC
write bltCntl
write srcStart = sx*bpp/8 + sy*line_length
write dstStart = dx*bpp/8 + dy*line_length
write xyExt    = (height << 16) | width                    ; TRIGGERS
```

**Mono imageblit** (accelerated glyph/text; `neo2200_imageblit`):
```
wait_idle()
write fgColor/bgColor = src colors
write bltCntl = BC0_SYS_TO_VID | BC3_SKIP_MAPPING | (depth==1 ? BC0_SRC_MONO : 0) | 0x0C0000
write srcStart = 0
write dstStart = dx*bpp/8 + dy*line_length
write xyExt    = (height << 16) | width
memcpy_toio(mmio + 0x100000, glyph_data, data_len)          ; staging area
```

## Known limitations / caveats (from upstream notes)

- 24 bpp color-expanded mono blit of images **narrower than 16 px is buggy**; driver
  falls back to `cfb_imageblit` in that case (`neofb.c` explicit FIXME).
- Image depth other than 1 bpp (mono) or the display depth is **not** hardware-accelerated
  → software fallback.
- The FIFO-space fast path is disabled upstream; only full `sync()` is reliable.
# NeoMagic 2D acceleration — architecture & X11 integration plan

## Goal

Expose the chip's BitBLT engine (solid fill, screen-to-screen blit, mono imageblit,
cursor) to X11/CDE so the Pentium III stops doing framebuffer copies in software.

## Key architectural fact

The BLT engine reads/writes **byte offsets into video RAM** (`srcStart`/`dstStart`) and
is triggered by a store to `xyExt`, all through the **BAR1 MMIO window**. This means it
can be driven **entirely from userspace** with two `mmap`s (BAR0 = pixels, BAR1 = BLT
registers) — no kernel patch is required for a first prototype. The kernel's `neofb.c`
is the reference for the exact sequences (already fully recovered).

## Option ranking (lowest-risk first)

### Option B — DDX (EXA) backend (recommended for L4)

Add an acceleration backend to the existing `xf86-video-neomagic` using **EXA**
(still present in xorg-server 21.x). EXA is the modern replacement for XAA's
acceleration interface and maps naturally:

| EXA hook | NeoMagic op |
|----------|-------------|
| `PrepareSolid` / `Solid` / `DoneSolid` | solid fill (`neo2200_fillrect`) |
| `PrepareCopy` / `Copy` / `DoneCopy` | screen-to-screen BLT (`neo2200_copyarea`) |
| (optional) `PrepareComposite` | unchanged → software |

Requirements / risks:
- EXA **pixmaps must live in VRAM** for offscreen copies; the 4 MB budget at 1024×768×16
  is tight but workable (CDE is not composited; no big offscreen surfaces).
- The engine has a real bug at 24 bpp mono-expand under 16 px (documented upstream) —
  keep `ImageWrite` on software, or stay at 16 bpp.
- Requires that the DDX run as the *primary* owner of the chip (unbind `neofb`/take over
  from BIOS VBE), i.e. the classic "legacy DDX does its own hardware setup" model.
- No DRM/KMS, no glamor — keeps the 2000s-style driver, which is appropriate for 64 MB.

### Option A — Restore XAA (broader, community request)

Re-introducing XAA into xorg-server 21.x would benefit **all** legacy chips ("not only
NeoMagic uses XAA"): s3, s3virge, tdfx, trident, sis, i810, siliconmotion, chips, etc.
This is a larger effort (restore `xaa*.c`/`xaa.h`, re-plumb the DDX ABI) and is exactly
what the GitHub request is about. Feasible but separate from the NeoMagic-specific
minimum. Recommended sequence: ship the NeoMagic EXA backend first (proves the engine +
integration), then generalize into an XAA restoration if there is appetite.

### Option C — Full DRM/KMS driver (`drivers/gpu/drm/neomagic`)

Modern atomic modeset + dumb buffers + a custom accel path. Most correct long-term, but
the largest and most invasive (kernel work, new modeset plumbing). **Not required** for
proof-of-concept; revisit only after L4/L5 are demonstrated.

## Abstraction layer (keep hardware semantics out of Xorg specifics)

```text
NeoMagicAccelOps
 ├── reset()            — engine reset sequence
 ├── wait_idle(timeout) — poll bltStat&1 with bounded timeout
 ├── solid_fill(x,y,w,h,color,rop)
 ├── copy(sx,sy,dx,dy,w,h)
 ├── image_write(dx,dy,w,h,mono_bits,fg,bg)   — glyph/text
 └── cursor(...)         — optional
```

`neofb.c` provides the reference implementation; `neomagic_diag` (see `NEOMAGIC_PHYSICAL_TEST.md`)
exercises `solid_fill`/`copy`/ROP standalone. The same ops are then callable from (a) the
standalone tool, (b) the EXA backend, and (c) a future DRM driver — one register layer,
three consumers.

## Synchronization & safety

- **Idle:** busy-bit `bltStat & 1` (proven). FIFO-space fast path is unreliable (disabled
  upstream) — use full `sync()`.
- **Timeout/must-have:** the kernel loop has **no timeout**. A new driver MUST
  implement `wait_idle(timeout_ms)`; on timeout, do NOT loop forever — reset the engine
  and fall back to software (CPUsafe). This is the single most important safety delta vs
  the reference code.
- **Reset:** recovery = re-init the register block (`bltStat`=bltMod<<16, `pitch`,
  colors) + drop to software for the failed op. Physical reset sequence beyond VGA state
  restore is not documented → keep software fallback rather than hard-resetting.

## Tearing / correctness

- CDE doesn't need vsync; the BLT is issued in draw order and `sync()` before the
  close-of-frame keeps frames coherent. Risk of partial-copy artifacts is mitigated by
  waiting for idle at operation boundaries.

## Memory budget (64 MB constraint)

- No shadow framebuffer when accelerated (the engine writes VRAM directly) — this is
  the RAM win: shadowfb currently holds a second full-screen buffer.
- EXA offscreen size must be capped so VRAM (4 MB) is not exhausted at 1024×768×16
  (1.57 MB framebuffer). No duplicated framebuffer, no userspace caches.
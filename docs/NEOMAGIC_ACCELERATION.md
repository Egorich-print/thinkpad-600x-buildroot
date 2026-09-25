# NeoMagic — acceleration integration & validation matrix

This is the execution plan that spans `NEOMAGIC_ARCHITECTURE.md` (design) and the
actual build. See `NEOMAGIC.md` for the level classification.

## Phase 0 — evidence (DONE)

- Register map + sequences recovered from GPL `neofb.c`/`neomagic.h` (HIGH confidence) —
  `docs/NEOMAGIC_REGISTER_MAP.md`.
- Corrected prior docs; confirmed no public datasheet, no emulator model.

## Phase 1 — standalone hardware proof (`tools/neomagic_diag`)

A static-ish C tool (no Rust needed; stack is C) that, **on the physical 600X**:

1. finds the device by PCI ID `0x10c8:0x0006`;
2. `mmap`s BAR0 (fb) + BAR1 (MMIO);
3. waits for the engine to become idle and uses the selected geometry;
4. `neo2200_accel_init` equivalent (depth/pitch);
5. `--test-fill` → solid fill, verify pixels via fb read-back;
6. `--test-blit` → screen-to-screen copy incl. overlap direction test;
7. `--test-rop` → copy vs xor observable difference;
8. `wait_idle(timeout)`, then re-initialize the non-triggering depth/pitch state.

Failure must be **non-destructive** (on normal completion the tool waits for idle
and re-initializes the non-triggering depth/pitch state; a timeout aborts). It
does not write unknown MMIO. See `NEOMAGIC_PHYSICAL_TEST.md`.

## Phase 2 — kernel safety prerequisites (if we touch the kernel)

Only needed for Option C (DRM) — the EXA path is userspace-only. Any kernel work must:
- bound the busy-wait (timeout + reset/fallback), and
- never fuzz undocumented MMIO.

## Phase 3 — X11 EXA backend (Option B, recommended)

- Vendor/fork `xf86-video-neomagic`; add `neo_accel` module implementing EXA Solid+Copy
  over the recovered `NeoMagicAccelOps`.
- Keep shadowfb as the automatic fallback when accel init fails/at unsupported depth.
- Gate acceleration off at 24 bpp (mono-expand bug) unless fixed.

## Phase 4 — image integration (Buildroot)

- Package switch to the fork (local tarball/git); `xorg.conf` `AccelMethod`/`Driver
  "neomagic"` on the physical profile.
- Kernel: `CONFIG_FB_NEOMAGIC` already present (the console acceleration path is
  configured). No change is needed for the userspace path.

## Phase 5 — benchmarks & validation

- `tools/neomagic-bench`: microbenchmarks (fill 1000×1000, copy 800×600/100×100/640×480,
  scroll) at 8/16 bpp, software vs hardware.
- Realistic CDE workload (dtterm scroll, dtfile redraw, window move) — see
  `NEOMAGIC_BENCHMARKS.md`.
- Only measured values make it into the final table.

## Phase 6 — GitHub publish (community request, pending auth)

The patched Xorg/XAA work can be published, but this environment has **no GitHub
credentials** — I cannot push. I will prepare the repo content locally (patched driver,
register docs, `neomagic_diag`, benchmarks) so the user can push with their own `gh`
auth. The immediate publishable artifact is the NeoMagic EXA backend; the broader XAA
restoration is a follow-up.

## Failure / fallback contract

- Accelerator hang/timeout/garbage output → bounded wait, engine re-init, **software
  fallback**, never a kernel lockup.
- All three candidate images (A software, B accelerated, C debug) must boot on 64 MB.
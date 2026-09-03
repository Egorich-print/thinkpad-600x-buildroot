# neomagic_diag — hardware test over SSH

Standalone, static, userspace tool that proves (or disproves) NeoMagic 256ZX BitBLT
acceleration on the physical ThinkPad 600X. It maps PCI BAR0 (framebuffer) + BAR1
(MMIO) and drives only the documented BLT registers (recovered from the kernel's
GPL `neofb.c`/`neomagic.h`). No kernel module, no undocumented writes.

## Why this cannot crash the machine

- userspace `mmap` of the PCI resources — no kernel code loaded;
- writes a fixed, documented register block only (offsets `0x00..0x30` of BAR1);
- `wait_idle()` is time-bounded (1000 ms start/end, 500 ms per op); a stuck engine
  aborts instead of spinning forever;
- no write-only registers are read back; `xyExt` (the BLT trigger) is never
  "restored";
- worst case on a misbehaving chip is a partially-drawn framebuffer, cleared by
  re-initializing the mode (reboot or re-run X).

## Pre-flight (over SSH)

```sh
# 1. confirm device + driver
lspci -nn | grep -i 10c8          # expect: 10c8:0006 (video) and 10c8:8006 (audio)
dmesg | grep -i neofb             # neofb binding, "(MagicGraph256ZX)"

# 2. best-effort quiescent state: no X drawing, console idle
#    (the tool works with neofb loaded; it just must not race concurrent fbcon draws)
```

## Run

```sh
neomagic_diag --dry-run           # safe: print identity + BLT status, write nothing
neomagic_diag --test-fill         # solid fill, verify pixel, time
neomagic_diag --test-blit         # screen-to-screen copy, verify, time
neomagic_diag --test-rop          # copy vs xor, verify
```

Expected healthy output ends with `OK (engine working)`. A `FAIL` line says which
verification failed; the tool still exits without touching anything else and leaves
the engine idle + re-initialised.

Interpretation key:
- `--dry-run` prints `BLT status: ... busy=0` → engine present/idle.
- fill pixel `0xF81F` OK → solid-fill engine confirmed.
- blit pixel `0xF800` OK → screen-to-screen BLT confirmed.
- xor pixel `0x07E0` OK → ROP (copy vs xor) confirmed.

## If it does NOT work (diagnosis)

| Symptom | Meaning | Next step |
|---------|---------|-----------|
| `not found` | device differs from `10c8:0006` (e.g. NM2200/2160) | read actual `lspci -nn`; rebuild tool w/ correct device id |
| `open resource0/resource1` fails | BAR not mappable (BIOS/PCI quirk) | `cat /sys/bus/pci/devices/*/resource{,0,1}`; retry with `iomem=relaxed` |
| `engine busy at start` | engine stuck before test | console is hot (fbcon drawing) — stop X, go to a quiet VT |
| `wait_idle: TIMEOUT` | engine did not drain | bad du/width/pitch vs real mode; verify `-b`/`-w` match the active fb mode |
| fill `OK` but blit `FAIL` | copy path issue (pitch/direction) | confirm `line_length` (try `-w` = real xres) |

## Notes for the builder

```sh
make CROSS_COMPILE=$HOME/br2-out/host/bin/i686-linux-   # cross for the 600X
```
The tool is also built into the Buildroot image via the `neomagic-diag` package
(`BR2_PACKAGE_NEOMAGIC_DIAG`), installed to `/usr/bin/neomagic_diag`.
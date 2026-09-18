# ADR-001 — Target platform & toolchain

- **Status:** accepted
- **Date:** 2026-08-31

## Context

The IBM ThinkPad 600X 2645-4EU is a Pentium III 500 MHz (Katmai) with 64 MB RAM
(55 MB usable), a NeoMagic 256ZX GPU (2D only), IDE/PATA storage and a Crystal
CS46xx audio chip.  It is a 1999 machine with a 1999 BIOS.

## Decision

- Target **i686** via Buildroot `BR2_x86_pentium3` → `-march=pentium3 -mtune=pentium3`.
  This is MMX + SSE but **no SSE2** — important, it is the correct baseline for Katmai.
- **glibc** (not musl/uClibc-ng): CDE/OpenMotif is a glibc-era stack (SunRPC → libtirpc).
- Buildroot as a `br2-external` tree; build host is a Linux aarch64 VM (lima `br2`),
  since Buildroot requires a GNU/Linux host and cross i686-on-aarch64 is fine.
- gcc 14.x, `-O2`; kernel built with `CC_OPTIMIZE_FOR_SIZE` (`-Os`).
- QEMU validation uses `qemu-system-i386 -cpu pentium3` (i386 = the 32-bit x86
  emulator, not "80386-only").

## Consequences

No code may assume SSE2.  Go uses `GO386=softfloat`; Rust is out (see ADR-010).

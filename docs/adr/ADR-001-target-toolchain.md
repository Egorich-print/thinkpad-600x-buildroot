# ADR-001 — Target platform & toolchain

- **Status:** accepted
- **Date:** 2026-08-31

## Context

The IBM ThinkPad 600X 2645-4EU is a Pentium III 500 MHz (Katmai) with 64 MB RAM
(55 MB usable), a NeoMagic 256ZX GPU (2D only), IDE/PATA storage and a Crystal
CS46xx audio chip.  It is a 1999 machine with a 1999 BIOS.

## Decision

- Target **i686** via Buildroot `BR2_x86_pentium3`, which supplies
  `-march=pentium3`; `BR2_TARGET_OPTIMIZATION="-mtune=pentium3"` adds the matching
  tuning.  This is MMX + SSE but **no SSE2** — the correct baseline for Katmai.
- Use the internal Buildroot **glibc** C/C++ toolchain
  (`BR2_TOOLCHAIN_BUILDROOT_GLIBC=y`, `BR2_TOOLCHAIN_BUILDROOT_CXX=y`), not
  musl/uClibc-ng: CDE/OpenMotif is a glibc-era SunRPC stack (`libtirpc` supplies RPC).
- Use gcc 14.x (`BR2_GCC_VERSION_14_X=y`) and userspace Linux headers 6.12
  (`BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_12=y`).  The kernel uses
  `CONFIG_MPENTIUMIII=y` and `CONFIG_CC_OPTIMIZE_FOR_SIZE=y` (`-Os`).
- Buildroot is a `br2-external` tree; the build host is a Linux aarch64 VM
  (lima `br2`), since Buildroot requires a GNU/Linux host and cross
  i686-on-aarch64 is supported.
- QEMU validation uses `qemu-system-i386 -cpu pentium3` (i386 = the 32-bit x86
  emulator, not "80386-only").

## Consequences

No code may assume SSE2.  Go uses `GO386=softfloat`; Rust is out (see ADR-010).

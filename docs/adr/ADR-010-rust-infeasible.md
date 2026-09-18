# ADR-010 — Rust rejected for the Pentium III (SSE2 baseline)

- **Status:** accepted
- **Date:** 2026-09-16

## Context

A native rewrite of small tools (e.g. a terminal aquarium to replace the Perl
`asciiquarium`) was considered in Rust.  Buildroot builds its Rust target as
**`i686-unknown-linux-gnu`**, whose standard library baseline is **Pentium 4 /
SSE2**.  Katmai (Pentium III) has no SSE2, so such a binary would die with
`SIGILL`.  The alternative target `i586-unknown-linux-gnu` is Tier 3 → requires
nightly and `build-std` (compiling `core`/`std`), which is disproportionate for
terminal toys.

## Decision

- Do **not** use Rust for target-side tools.
- Write such tools in **C** (e.g. `tools/aquarium/aquarium.c`: ncurses only,
  fixed-point, no SSE — verified 0 SSE/SSE2 instructions in the binary, 13 KB).
- If Rust is ever required, it must be `i586-unknown-linux-gnu` with `build-std`.

## Consequences

Native tools stay small and SSE-free.  Go remains usable via `GO386=softfloat`.

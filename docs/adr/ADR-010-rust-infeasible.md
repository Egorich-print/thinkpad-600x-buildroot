# ADR-010 — Rust rejected for the Pentium III (SSE2 baseline)

- **Status:** accepted
- **Date:** 2026-09-16

## Context

A native rewrite of small tools (e.g. a terminal aquarium to replace the Perl
`asciiquarium`) was considered in Rust.  Buildroot builds its Rust target as
**`i686-unknown-linux-gnu`**, whose standard library baseline is **Pentium 4 /
SSE2**.  Katmai (Pentium III) has no SSE2, so such a binary would die with
`SIGILL`.  The alternative `i586-unknown-linux-gnu` target is Tier 2 (without
host tools) and has a prebuilt `std`; it does not require nightly or `build-std`.

## Decision

- Do **not** use Rust for target-side tools.
- Write such tools in **C** (e.g. `tools/aquarium/aquarium.c`: ncurses and
  fixed-point state, with no explicit SIMD or SSE2 dependency).
- If Rust is ever required as an exception, it must explicitly use the
  `i586-unknown-linux-gnu` target rather than Buildroot's i686 target.

## Consequences

Native tools stay small and target-compatible.  Go remains usable via
`GO386=softfloat`.

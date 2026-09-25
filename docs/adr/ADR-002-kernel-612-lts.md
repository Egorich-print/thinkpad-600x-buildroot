# ADR-002 — Kernel base: Linux 6.12 LTS

- **Status:** accepted (supersedes the initial 6.18 choice)
- **Date:** 2026-09-03

## Context

The first build used a 6.18 line, which hung on the 440BX/Pentium III during
BogoMIPS calibration.  The 440BX APIC/PIT pair is unreliable and tickless idle
plus aggressive clocksource selection makes it worse.

## Decision

- Pin **Linux 6.12.104 (LTS)** as the kernel base.
- Turn off the risky 440BX features: `CONFIG_NO_HZ_IDLE` **off**, `CONFIG_CPU_FREQ`
  **off** (Katmai has no SpeedStep), `CONFIG_HZ_100=y`, and boot with
  `clocksource=jiffies tsc=unstable`.
- `CONFIG_ACPI_VIDEO` off (it fights `CONFIG_THINKPAD_ACPI` for the backlight).
- Keep the in-tree `neofb` NeoMagic framebuffer (the console path).

## Consequences

The selected configuration keeps the kernel on an LTS line with in-tree NeoMagic
support and no reliance on DRM/KMS for the panel.  The repository does not contain
a physical-600X boot log for this kernel, so hardware stability is not claimed here.

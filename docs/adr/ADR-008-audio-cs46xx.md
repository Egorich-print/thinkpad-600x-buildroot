# ADR-008 — Audio: Crystal CS46xx with fetched non-free firmware

- **Status:** accepted
- **Date:** 2026-09-14

## Context

The 600X has a Crystal/Cirrus CS 4614/22/24/30 "SoundFusion" audio controller
driven by `CONFIG_SND_CS46XX=m`, which needs external DSP firmware
(`cs46xx/ba1`, `cwc4630`, `cwcasync`, `cwcbinhack`, `cwcdma`, and `cwcsnoop`).
That firmware was removed from linux-firmware (unknown/non-free licence).

## Decision

- Fetch the blobs at build time from the **alsa-firmware** tarball via
  `scripts/fetch-cs46xx-firmware.sh`, which drops them into the rootfs overlay
  (`/lib/firmware/cs46xx/`).
- Keep the blobs **out of git** (`.gitignore`), since they are non-free.
- `snd-cs46xx` is auto-loaded from `/etc/modules`; `alsa-utils`
  (`aplay`, `amixer`, `alsactl`, and `speaker-test`) is included for testing.

## Consequences

The firmware, module, and test utilities are present in the built image, but the
repository contains no `aplay` or `speaker-test` evidence from the physical
600X; audio validation is still pending.  A fresh clone must run the fetch
script before building (otherwise the firmware is absent; boot is unaffected).

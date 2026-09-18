# ADR-008 — Audio: Crystal CS46xx with fetched non-free firmware

- **Status:** accepted
- **Date:** 2026-09-14

## Context

The 600X has a Crystal/Cirrus CS 4614/22/24/30 "SoundFusion" audio controller
driven by `snd-cs46xx`, which is built with `CONFIG_SND_CS46XX_NEW_DSP=y` and
needs external DSP firmware (`cs46xx/cwc4630`, `cwcasync`, `cwcsnoop`,
`cwcbinhack`, `cwcdma`).  That firmware was removed from linux-firmware
(unknown/non-free licence).

## Decision

- Fetch the blobs at build time from the **alsa-firmware** tarball via
  `scripts/fetch-cs46xx-firmware.sh`, which drops them into the rootfs overlay
  (`/lib/firmware/cs46xx/`).
- Keep the blobs **out of git** (`.gitignore`), since they are non-free.
- `snd-cs46xx` is auto-loaded from `/etc/modules`; `alsa-utils`
  (`aplay`/`amixer`/`speaker-test`) is included for testing.

## Consequences

Sound works on the real hardware; a fresh clone must run the fetch script before
building (otherwise audio firmware is simply absent, boot is unaffected).

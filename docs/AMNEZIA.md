# Amnezia VPN 5.0.1.5 — feasibility report

**Status: PARTIAL — full GUI client impossible; AWG kernel-module client feasible.**

## Full GUI client (=5.0.1.5): NO

- The Linux 5.0.1.5 asset is a single `AmneziaVPN_5.0.1.5_linux_x64.run`
  (91.9 MB). **No i386/i686 build exists.**
- The client is **Qt 6** C++; Qt 6 has no 32-bit x86 desktop target at all. Even
  ignoring that, Qt 6 + Xray (Go) + OpenVPN ≫ 64 MB RAM and needs SSE2 (Go) /
  x86_64 (Qt).
- Any Go component (Xray) requires `GO386=softfloat` to run on the PIII and no such
  prebuilt binary ships.

## AmneziaWG (the VPN protocol itself): YES, as a pure-C client

AmneziaWG is an obfuscated WireGuard fork (DPI-resistant header/packet/timing
obfuscation). Two implementations:

- **`amneziawg-linux-kernel-module`** — fork of wireguard-linux-compat, **pure C**
  (GPL-2.0), DKMS/manual `make`. Builds for i686/PIII (generic C crypto fallback,
  no SSE2).
- **`amneziawg-tools`** — `awg(8)` / `awg-quick(8)`, **pure C, no deps** beyond a C
  compiler + sane libc.

Together they provide a **console-only AWG client** that interoperates with a
5.0.1.5-era server (AWG 3.1 obfuscation params), with no Qt, no Go, no Xray.

## ❌ — one bright point

The Go userspace path (`amneziawg-go`, or Xray) is the only *portable* obfuscated
path; the kernel module needs out-of-tree build/headers but those are trivially
available in Buildroot.

## Feasibility verdict

| Path | PIII / 64 MB? | Blocker |
|------|---------------|---------|
| Qt6 GUI 5.0.1.5 | No | Qt6 = x86_64-only; no i386; ≫64 MB RAM |
| Go userspace / Xray | Essentially no | SSE2 (softfloat rebuild only, no prebuilt) |
| **amneziawg kernel + awg-tools** | **Yes (headless)** | must match server AWG params; low throughput |

## Implementation plan

- Optional config flag `BR2_PACKAGE_AWG` / `BR2_PACKAGE_AWG_TOOLS` scaffolding.
- `CONFIG_WIREGUARD=m` (for the compat module) and `CONFIG_TUN=m` are already
  enabled in the kernel.
- Document that "5.0.1.5 or newer" applies to **protocol interoperability**, not
  the desktop application.
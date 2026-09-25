# Amnezia VPN 5.0.1.5 — feasibility report

**Status: PARTIAL (feasibility only) — the full GUI client is impossible; an AWG
kernel-module client is feasible in principle but is not available in this
Buildroot tree.**

## Full GUI client (=5.0.1.5): NO

- The Linux 5.0.1.5 asset is a single `AmneziaVPN_5.0.1.5_linux_x64.run`
  (91.9 MB). **No i386/i686 build exists.**
- The client is **Qt 6** C++; Qt 6 has no 32-bit x86 desktop target at all. Even
  ignoring that, Qt 6 + Xray (Go) + OpenVPN ≫ 64 MB RAM and needs SSE2 (Go) /
  x86_64 (Qt).
- Any Go component (Xray) requires `GO386=softfloat` to run on the PIII and no such
  prebuilt binary ships.

## AmneziaWG (the VPN protocol itself): feasible in principle, not packaged here

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
| **amneziawg kernel + awg-tools** | **Feasible in principle; unavailable in this tree** | no packages/kernel options; must match server AWG params |

## Implementation plan

- This is **not implemented**.  Neither `BR2_PACKAGE_AWG` nor
  `BR2_PACKAGE_AWG_TOOLS` exists in this external package tree or in
  `configs/thinkpad600x_defconfig`.
- `board/thinkpad600x/linux.config` does not enable `CONFIG_WIREGUARD` or
  `CONFIG_TUN`; no AWG module or tools are present in the built image.  No
  replacement Kconfig option is defined by this tree.
- Document that "5.0.1.5 or newer" applies to **protocol interoperability**, not
  the desktop application.

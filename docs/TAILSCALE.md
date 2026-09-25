# Tailscale — feasibility report

**Status: FEASIBILITY ONLY — not shipped in the default image (feasible on CPU, marginal on RAM).**

## 32-bit x86 support — package exists, image does not enable it

Buildroot 2026.05.2 provides the `tailscale` package
(`BR2_PACKAGE_TAILSCALE`), pinned to Tailscale 1.78.1 in
`package/tailscale/tailscale.mk`. `configs/thinkpad600x_defconfig` does not
select that symbol, so the default release contains neither `tailscale` nor
`tailscaled`. The Buildroot package is built with the host Go toolchain; it is
not a prebuilt `geode` archive. A separately downloaded official 386 release
would need the soft-float/geode variant rather than the ordinary SSE2 build;
that external deployment is not validated in this repository.

## CPU constraint (Go → SSE2)

- Go's 386 port dropped x87 (`GO386=387`) in Go 1.16; SSE2 is the *default*, not a
  hard requirement. `GO386=softfloat` still works in current Go and targets
  "Pentium MMX or later".
- Buildroot's `go.mk` already emits `GO386=softfloat` automatically when
  `BR2_X86_CPU_HAS_SSE2` is unset — which is the case for `BR2_x86_pentium3`.

## Data path

Tailscale always runs its own userspace WireGuard (never the kernel module), in
either TUN or `--tun=userspace-networking` (netstack/gVisor, no `/dev/net/tun`).
Userspace-networking is the right mode for the 600X (SOCK5/HTTP proxy).

## Memory (the real blocker)

No official minimum is specified here, and the commonly cited `tailscaled` RSS
of ~40–80 MB is an estimate, not a measurement of this image. On 64 MB it is at
or over the edge; a single basic node in userspace mode with `GOMEMLIMIT` tuned
is borderline-feasible, near OOM.

## Recommendation

- The default image does not ship Tailscale. `BR2_PACKAGE_TAILSCALE` is a valid
  optional Buildroot symbol, but it is not selected; enabling it also brings the
  host Go package and the package's kernel fixups (including `CONFIG_TUN` and
  netfilter), so it requires a separate rebuild and validation.
- If deployed manually, use a 386 soft-float/geode binary with
  `--tun=userspace-networking`; this remains an unvalidated plan, not a default
  image feature.
- Treat RAM, not CPU, as the likely limiter. The statement that it "works, but
  tight" is a risk assessment, not a recorded result.
- A separately built classic C `wg` client could be lighter, but no WireGuard or
  TUN support is enabled in the current kernel config; it is not a Tailscale
  client.

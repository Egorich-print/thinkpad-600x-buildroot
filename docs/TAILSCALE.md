# Tailscale — feasibility report

**Status: PARTIALLY FEASIBLE (feasible on CPU, marginal on RAM).**

## 32-bit x86 support — still ships

Tailscale still publishes `linux/386` static builds. The one that matters for the
600X is the **`geode` build**, a generic 386 **soft-float** binary:

```
https://pkgs.tailscale.com/stable/   (current: v1.102.3)
  tailscale_<ver>_386.tgz        -> GO386=sse2  (SIGILL on Pentium III)
  tailscale_<ver>_geode.tgz      -> GO386=softfloat  (runs pre-SSE2)
```

The plain `_386` build uses Go's default `GO386=sse2` and will crash on a
no-SSE2 CPU; **only the `geode` (softfloat) tarball runs on the Pentium III.**

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

No official minimum, but `tailscaled` RSS is typically ~40–80 MB (Go runtime). On
64 MB this is at/over the edge; a single basic node in userspace mode with
`GOMEMLIMIT` tuned is borderline-feasible, near OOM.

## Recommendation

- Main image: **Tailscale-capable via optional config flag**
  (`BR2_PACKAGE_TAILSCALE`), not enabled in the default 64 MB baseline.
- Deploy the official `geode` tarball + `--tun=userspace-networking`.
- Document that it "works, but tight" — RAM, not CPU, is the limiter.
- Where only a raw WireGuard tunnel is needed, classic C `wg`/kernel module remains
  the lighter option (but is not a Tailscale client).
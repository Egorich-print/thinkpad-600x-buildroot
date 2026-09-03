# Build instructions

## Host requirements

Buildroot requires a **GNU/Linux host** (it will not run natively on macOS). On an
Apple Silicon Mac, run an aarch64 Linux VM via lima/VZ (HVF-accelerated), which is
*faster than an x86 VM* for this use: the cross-toolchain (aarch64 host → i686
target) runs at native speed; only the final i386 *testing* guest uses TCG.

Base packages (Ubuntu 24.04):

```sh
sudo apt-get install -y \
  which sed make binutils build-essential diffutils gcc g++ bash patch gzip bzip2 \
  xz-utils perl tar cpio unzip rsync file bc findutils wget curl git python3 \
  python3-dev libncurses-dev bison flex gettext texinfo autoconf automake libtool \
  pkg-config zlib1g-dev libssl-dev ccache
```

CDE build-time host tools (paths are probed at `./configure`, not shipped):

```sh
sudo apt-get install -y mksh cpp xfonts-utils x11-xserver-utils rpcsvc-proto opensp ncompress
```

## Build

```sh
# 1. clone Buildroot (pinned)
git clone --depth 1 --branch 2026.05.2 https://github.com/buildroot/buildroot.git

# 2. build (out-of-tree)
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     -j"$(nproc)"
```

Outputs appear in `$HOME/br2-out/images/`:
- `bzImage` — kernel
- `rootfs.ext2` — ext2 filesystem
- `rootfs.tar` — tarball of the rootfs

## Incremental iteration

- Change a package/kernel config → `make O=... <pkg>-rebuild` or `linux-rebuild`.
- Change a custom package `.mk` → `make O=... <pkg>-dirclean <pkg>`.
- Change the rootfs overlay → `make O=...` will re-apply during `target-finalize`;
  if in doubt `make O=... clean` performs a full (but ccache-accelerated) rebuild.

> Do **not** `rm -rf output/target` manually — it desynchronizes the skeleton and
> busybox init installs. Use the `make` targets above.

## QEMU test (from macOS)

`qemu-system-i386` (≥ 9.x) is used with TCG (x86 cannot be HVF-accelerated on Apple
Silicon):

```sh
scripts/qemu_test.sh            # headless boot + SSH diagnostics (port 2222)
```

Manual boot:

```sh
qemu-system-i386 -m 64M -cpu pentium3 -M pc \
  -kernel bzImage -append "root=/dev/sda rw console=ttyS0" \
  -drive file=rootfs.ext2,format=raw,if=ide -nographic
```

## Reproducibility

- Buildroot version/commit: **2026.05.2** (`Makefile: Update for 2026.05.2`).
- Kernel version: **6.18.7** (custom version, no hash — pin known-good).
- Toolchain: internal, gcc **14.4.0**, binutils default, headers **6.18**.
- Custom package versions are pinned in each `package/*/*.mk`.
- CDE source is vendored (`cde-2.5.3.tar.gz`) into `$BR2_DL_DIR` because the
  SourceForge release path is unstable.
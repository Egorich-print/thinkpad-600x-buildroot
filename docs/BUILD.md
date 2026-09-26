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

Live-ISO tools (used by `scripts/make-live-iso.sh`; `isolinux` supplies
`isolinux.bin`, `isohdpfx.bin`, and `ldlinux.c32`):

```sh
sudo apt-get install -y cpio gzip xorriso isolinux
```

## Build VM (lima `br2`)

`scripts/lima.buildroot.yaml` defines the build VM: vz/aarch64, 10 CPUs, 16 GiB
RAM, 121 GiB disk, Ubuntu 24.04 cloud image. The template matches the live `br2`
instance.

The host home is **deliberately not mounted** in the VM, so the project tree is
not visible from inside and has to be copied in:

```sh
# host: pack the tree (run from the parent directory of the project)
COPYFILE_DISABLE=1 tar --exclude='._*' -czf /tmp/src.tar.gz \
    --exclude=release --exclude=.git -C <parent> thinkpad-600x-buildroot
limactl copy /tmp/src.tar.gz br2:~/src.tar.gz
limactl shell br2 -- tar -xzf ~/src.tar.gz -C ~
```

Then build inside the instance:

```sh
limactl shell br2 -- bash -c 'make O=$HOME/br2-out \
    BR2_EXTERNAL=$HOME/thinkpad-600x-buildroot thinkpad600x_defconfig && \
    make O=$HOME/br2-out BR2_EXTERNAL=$HOME/thinkpad-600x-buildroot -j10'
```

> AppleDouble `._*` sidecars must never reach the build tree: they end up inside
> the shipped image, and `scripts/check.sh` fails if `release/rootfs.tar`
> contains any. `COPYFILE_DISABLE=1` is what stops macOS `tar` from creating
> them in the first place.

## Build

```sh
# 1. fetch the non-free CS46xx DSP firmware into the rootfs overlay (once)
./scripts/fetch-cs46xx-firmware.sh

# 2. clone Buildroot (pinned)
git clone --depth 1 --branch 2026.05.2 https://github.com/buildroot/buildroot.git

# 3. build (out-of-tree)
#    in the lima `br2` VM the tree is not on a mounted host filesystem —
#    copy it in first, see "Build VM (lima br2)" above
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     thinkpad600x_defconfig
make O=$HOME/br2-out \
     BR2_EXTERNAL=/abs/path/to/thinkpad-600x-buildroot \
     -j"$(nproc)"
```

Outputs appear in `$HOME/br2-out/images/`:
- `bzImage` — Linux 6.12.104 kernel
- `rootfs.ext2` — 512 MiB ext4 filesystem image (despite its filename), with
  neither a partition table nor a bootloader; it is not a bootable disk image
- `rootfs.tar` — tarball of the root filesystem tree

## Incremental iteration

- Change a package/kernel config → `make O=... <pkg>-rebuild` or `linux-rebuild`.
- Change a custom package `.mk` → `make O=... <pkg>-dirclean <pkg>`.
- Change the rootfs overlay → `make O=...` will re-apply during `target-finalize`;
  if in doubt `make O=... clean` performs a full (but ccache-accelerated) rebuild.

> Do **not** `rm -rf $HOME/br2-out/target` manually — it desynchronizes the
> skeleton and busybox init installs. Use the `make` targets above.

## QEMU test (from macOS)

`qemu-system-i386` (≥ 9.x) is used with TCG (x86 cannot be HVF-accelerated on Apple
Silicon):

```sh
scripts/qemu_test.sh            # headless boot + SSH diagnostics (port 2222)
```

Manual boot:

```sh
qemu-system-i386 -m 64M -cpu pentium3 -M pc \
  -kernel release/bzImage \
  -append "root=/dev/sda rw console=ttyS0,115200 console=tty0 acpi=off clocksource=jiffies tsc=unstable" \
  -drive file=release/rootfs.ext2,format=raw,if=ide,snapshot=on -nographic
```

## X11 input

The image uses devtmpfs + mdev, not udev. `xf86-input-evdev` is therefore
unavailable; the classic `mouse` and `kbd` drivers are built as external
Buildroot packages (`package/xf86-input-mouse` and
`package/xf86-input-keyboard`). `board/thinkpad600x/rootfs-overlay/etc/X11/xorg.conf`
binds `mouse` to `/dev/input/mice` and `kbd` to the PS/2 keyboard. No prebuilt
input `.so` files should be copied into the overlay.

## Live ISO and boot

With `release/bzImage` and `release/rootfs.tar` present, build the hybrid
CD/USB ISO from the project root:

```sh
./scripts/make-live-iso.sh
```

The isolinux menu has three entries: `1` — Live CDE, `2` — Live Safe, and `3`
— Install to internal HDD (`/dev/sda`). For physical installation, choose `3`
and type `YES` when prompted; see `docs/DEPLOY.md`.

The live entries omit `root=`. The supplied kernel accepts only
`PARTUUID=`, `PARTLABEL=`, `/dev/<name>`, and `MAJOR:MINOR` for `root=`, not
`LABEL=`; `board/thinkpad600x/initramfs/init` therefore finds the ISO by its
contents, mounts it with a RAM-backed overlayfs, and uses `switch_root`.
The **last** `console=` becomes `/dev/console`, so the working order is
`console=ttyS0,115200 console=tty0` — `tty0` last.

The installer creates `/dev/sda1` with
`mkfs.ext4 -O ^metadata_csum,^orphan_file,^64bit`, because extlinux 6.03 cannot
read a directory on an ext4 filesystem carrying those features. The generated
`rootfs.ext2` uses the same exclusions through
`BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS`.

## Reproducibility

- Buildroot used by the release: **2026.05.2**; the clone command above pins it.
- Kernel version: **6.12.104** (custom version, no VCS pin).
- Toolchain: internal Buildroot GCC **14.x**, glibc, and custom kernel headers
  **6.12**, selected by `thinkpad600x_defconfig`.
- CDE **2.5.3** and OpenMotif **2.3.8** are pinned in `package/cde/cde.mk` and
  `package/openmotif/openmotif.mk`; other custom package versions are pinned in
  their respective `package/*/*.mk` files.
- The package recipes define upstream source URLs. CDE may also be supplied
  through `$BR2_DL_DIR`; the repository does not require a vendored tarball.

#!/bin/bash
# check.sh — fast, host-only sanity checks (no Buildroot build required).
#
# Covers the failure modes that have actually bitten this project: BusyBox-incompatible
# shell, unreadable installer, SSE2 creeping into target code, unverified external
# sources, and a kernel config that lost something the initramfs depends on.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
fails=0
ok()   { printf '  ok   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fails=$((fails + 1)); }
run()  { if "$@" >/dev/null 2>&1; then ok "$*"; else bad "$*"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== shell syntax =="
for f in board/thinkpad600x/initramfs/init \
         board/thinkpad600x/post-build.sh \
         board/thinkpad600x/rootfs-overlay/etc/init.d/* \
         board/thinkpad600x/rootfs-overlay/usr/sbin/autostart-cde; do
    run sh -n "$f"
done
for f in scripts/*.sh; do
    run bash -n "$f"
done

echo "== installer (embedded heredoc) =="
if sed -n "/<<'EOS'/,/^EOS$/p" scripts/make-live-iso.sh | sed '1d;$d' > "$TMP/install-live.sh" \
   && [ -s "$TMP/install-live.sh" ]; then
    run sh -n "$TMP/install-live.sh"
    grep -q 'switch_root' board/thinkpad600x/initramfs/init \
        && grep -q 'case "$CD" in' "$TMP/install-live.sh" \
        && ok "installer refuses the live medium" \
        || bad "installer lost the live-medium guard"
else
    bad "could not extract the installer heredoc"
fi

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
    for f in board/thinkpad600x/initramfs/init board/thinkpad600x/post-build.sh \
             board/thinkpad600x/rootfs-overlay/etc/init.d/* \
             board/thinkpad600x/rootfs-overlay/usr/sbin/autostart-cde \
             scripts/*.sh "$TMP/install-live.sh"; do
        if shellcheck -S warning -e SC1091 "$f" >"$TMP/sc.out" 2>&1; then
            ok "shellcheck $f"
        else
            bad "shellcheck $f"; sed 's/^/       /' "$TMP/sc.out"
        fi
    done
else
    echo "  skip shellcheck (not installed)"
fi

echo "== C tools: no warnings =="
CC="${CC:-cc}"
for c in tools/aquarium/aquarium.c tools/neomagic_diag/neomagic_diag.c; do
    if $CC -std=gnu89 -Wall -Wextra -fsyntax-only "$c" >"$TMP/cc.out" 2>&1; then
        ok "$c"
    else
        bad "$c"; sed 's/^/       /' "$TMP/cc.out"
    fi
done

echo "== target ISA =="
if grep -qE '(^|[[:space:]])-march=(native|x86-64|haswell|skylake|znver)' configs/thinkpad600x_defconfig \
   package/*/*.mk tools/*/*.c 2>/dev/null; then
    bad "a -march newer than pentium3 is configured"
else
    ok "no -march beyond pentium3"
fi
grep -q 'BR2_x86_pentium3=y' configs/thinkpad600x_defconfig \
    && ok "BR2_x86_pentium3" || bad "BR2_x86_pentium3 is not set"

echo "== external sources are pinned =="
for mk in package/*/*.mk; do
    d="$(dirname "$mk")"
    pkg="$(basename "$mk" .mk)"
    upper="$(printf '%s' "$pkg" | tr 'a-z-' 'A-Z_')"
    method="$(sed -n "s/^${upper}_SITE_METHOD[[:space:]]*=[[:space:]]*//p" "$mk" | head -1)"
    src="$(sed -n "s/^${upper}_SOURCE[[:space:]]*=[[:space:]]*//p" "$mk" | head -1)"
    if [ "$method" = "local" ]; then
        ok "$pkg: local source (built from this tree, nothing to pin)"
        continue
    fi
    hashf="$d/$pkg.hash"
    if [ ! -f "$hashf" ]; then
        bad "$pkg: downloaded but no $pkg.hash"
        continue
    fi
    if [ -z "$src" ]; then
        ok "$pkg: hash present, source name derived by the infrastructure"
        continue
    fi
    while [[ "$src" == *'$('* ]]; do
        var="${src#*\$\(}"; var="${var%%\)*}"
        val="$(sed -n "s/^${var}[[:space:]]*=[[:space:]]*//p" "$mk" | head -1)"
        src="${src/\$\($var\)/$val}"
    done
    if awk -v s="$src" '$3 == s && $1 ~ /^(md5|sha1|sha224|sha256|sha384|sha512)$/ {found=1} END{exit !found}' "$hashf"; then
        ok "$pkg: $src"
    else
        bad "$pkg: $pkg.hash has no valid line for $src"
    fi
done

echo "== kernel config invariants =="
while read -r opt; do
    grep -qx "$opt" board/thinkpad600x/linux.config && ok "$opt" || bad "$opt missing"
done <<'EOF'
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_DEVTMPFS=y
CONFIG_OVERLAY_FS=y
CONFIG_ISO9660_FS=y
CONFIG_EXT4_FS=y
CONFIG_USB_STORAGE=y
CONFIG_USB_UHCI_HCD=y
CONFIG_ATA_PIIX=y
CONFIG_BLK_DEV_SR=y
CONFIG_BLK_DEV_SD=y
CONFIG_MPENTIUMIII=y
EOF
for dead in "CONFIG_CGROUPS=y" "CONFIG_NETFILTER=y" "CONFIG_TUN=m" "CONFIG_WIREGUARD=m" "CONFIG_BT=y"; do
    grep -qx "$dead" board/thinkpad600x/linux.config && bad "dead option back: $dead" || ok "removed $dead"
done

echo "== defconfig invariants =="
while read -r opt; do
    grep -qx "$opt" configs/thinkpad600x_defconfig && ok "$opt" || bad "$opt missing"
done <<'EOF'
BR2_x86_pentium3=y
BR2_PACKAGE_XF86_INPUT_MOUSE=y
BR2_PACKAGE_XF86_INPUT_KEYBOARD=y
BR2_TARGET_ROOTFS_EXT2_MKFS_OPTIONS="-O ^metadata_csum,^orphan_file,^64bit"
EOF
grep -qx 'BR2_ROOTFS_LABEL="THINKPAD600X_LIV"' configs/thinkpad600x_defconfig \
    && bad "BR2_ROOTFS_LABEL is a no-op for the ext2 generator" \
    || ok "no no-op BR2_ROOTFS_LABEL"

echo "== initramfs can actually run =="
TAR=release/rootfs.tar
if [ ! -f "$TAR" ]; then
    echo "  skip (release/rootfs.tar not built yet)"
elif ! command -v objdump >/dev/null 2>&1 && ! command -v readelf >/dev/null 2>&1; then
    echo "  skip (no objdump/readelf)"
else
    tar -xf "$TAR" -C "$TMP" ./bin/busybox 2>/dev/null
    if command -v objdump >/dev/null 2>&1; then
        needed="$(objdump -p "$TMP/bin/busybox" 2>/dev/null | awk '/NEEDED/ {print $2}')"
    else
        needed="$(readelf -d "$TMP/bin/busybox" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')"
    fi
    listing="$(tar -tf "$TAR")"
    for lib in $needed ld-linux.so.2; do
        esc="${lib//./\\.}"
        if grep -qE "^\./(usr/)?lib/${esc}(\.[0-9.]+)*$" <<< "$listing"; then
            ok "initrd library present: $lib"
        else
            bad "busybox needs $lib but release/rootfs.tar does not contain it"
        fi
    done
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
else
    echo "$fails checks failed"
fi
exit $((fails > 0))

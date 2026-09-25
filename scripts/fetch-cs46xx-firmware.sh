#!/bin/bash
# fetch-cs46xx-firmware.sh
#
# The Crystal/Cirrus CS46xx DSP firmware is not distributed with linux-firmware
# (unknown/non-free license), so it is not committed to this repository.  The
# snd-cs46xx driver (the ThinkPad 600X's sound chip) needs these files in
# /lib/firmware/cs46xx/:
#
#     ba1 cwc4630 cwcasync cwcbinhack cwcdma cwcsnoop
#
# They ship in the alsa-firmware tarball.  Run this script once before building;
# the files are copied into the rootfs overlay and picked up by the image build.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$PROJECT_DIR/board/thinkpad600x/rootfs-overlay/lib/firmware/cs46xx"
VER="${ALSA_FIRMWARE_VER:-1.2.4}"
URL="https://www.alsa-project.org/files/pub/firmware/alsa-firmware-${VER}.tar.bz2"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading alsa-firmware ${VER} ..."
curl -fsSL -o "$TMP/alsa-firmware.tar.bz2" "$URL"

echo "Extracting cs46xx firmware ..."
tar xjf "$TMP/alsa-firmware.tar.bz2" -C "$TMP" "alsa-firmware-${VER}/cs46xx"

mkdir -p "$DEST"
missing=""
for f in ba1 cwc4630 cwcasync cwcbinhack cwcdma cwcsnoop; do
    src="$TMP/alsa-firmware-${VER}/cs46xx/$f"
    if [ -f "$src" ]; then
        cp "$src" "$DEST/$f"
    else
        missing="$missing $f"
    fi
done
# A half-populated firmware directory boots fine and then fails in snd-cs46xx,
# so never leave one behind.
if [ -n "$missing" ]; then
    echo "ERROR: not in alsa-firmware-${VER}:$missing" >&2
    rm -rf "$DEST"
    exit 1
fi

echo "Installed into $DEST:"
ls -l "$DEST"

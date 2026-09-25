#!/bin/bash
# QEMU smoke test for the ThinkPad 600X image.
# Boots the kernel+rootfs, waits for dropbear, and runs diagnostics over SSH.
set -euo pipefail

IMGDIR="${IMGDIR:-$(cd "$(dirname "$0")/../release" && pwd)}"
BZIMAGE="${BZIMAGE:-$IMGDIR/bzImage}"
ROOTFS="${ROOTFS:-$IMGDIR/rootfs.ext2}"
SSHPORT="${SSHPORT:-2222}"
SSHPASS_BIN="$(command -v sshpass || true)"
MEMSIZE="${MEMSIZE:-64}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o LogLevel=ERROR"

# The image is a release artifact: never let a smoke test modify it.
LOG="$IMGDIR/qemu-smoke.log"

for f in "$BZIMAGE" "$ROOTFS"; do
  [ -f "$f" ] || { echo "[qemu] missing $f (build first, or set BZIMAGE/ROOTFS)"; exit 1; }
done

qemu-system-i386 -m "${MEMSIZE}M" -cpu pentium3 -M pc \
  -kernel "$BZIMAGE" -append "root=/dev/sda rw console=ttyS0 panic=-1" \
  -drive file="$ROOTFS",format=raw,if=ide,snapshot=on \
  -netdev user,id=n0,hostfwd=tcp::${SSHPORT}-:22 \
  -device e1000,netdev=n0 \
  -nographic -no-reboot > "$LOG" 2>&1 &
QPID=$!
trap 'kill "$QPID" 2>/dev/null' EXIT

echo "[qemu] booting (pid $QPID), waiting for dropbear…"
up=0
i=0
while [ "$i" -lt 60 ]; do
  # root has an empty password, so probe the port instead of authenticating.
  if (exec 3<>"/dev/tcp/127.0.0.1/$SSHPORT") 2>/dev/null; then up=1; break; fi
  i=$((i + 1))
  sleep 2
done

if [ "$up" != 1 ]; then
  echo "[qemu] FAILED: sshd never came up"; tail -30 "$LOG"; exit 1
fi
echo "[qemu] sshd up after ~$((i*2))s"

run() {
  if [ -z "$SSHPASS_BIN" ]; then
    echo "  (sshpass not installed - skipping: $*)"
    return 0
  fi
  "$SSHPASS_BIN" -p '' ssh $SSH_OPTS -o PreferredAuthentications=password \
    -p "$SSHPORT" root@127.0.0.1 "$@"
}

echo "=== uname ==="; run "uname -a"
echo "=== cpu ==="; run "grep -m1 'model name' /proc/cpuinfo"
echo "=== mem free ==="; run "free -m"
echo "=== hostname ==="; run "hostname"
echo "=== net ==="; run "ip -o addr show eth0"
echo "=== storage ==="; run "df -h /"
echo "=== optional drivers present? ==="; run "find /lib/modules -name 'mt7601u*' -o -name 'rt2800usb*' -o -name 'thinkpad_acpi*' -o -name 'snd-cs46xx*' | sort"
echo "=== process count ==="; run "ps | wc -l"
echo "[qemu] DONE"
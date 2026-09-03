#!/bin/bash
# QEMU smoke test for the ThinkPad 600X image.
# Boots the kernel+rootfs, waits for dropbear, and runs diagnostics over SSH.
set -u

IMGDIR="$(cd "$(dirname "$0")/../images" && pwd)"
BZIMAGE="${BZIMAGE:-$IMGDIR/bzImage}"
ROOTFS="${ROOTFS:-$IMGDIR/rootfs.ext2}"
SSHPORT="${SSHPORT:-2222}"
SSHPASS_BIN="$(command -v sshpass)"
MEMSIZE="${MEMSIZE:-64}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3"

LOG="$IMGDIR/qemu-smoke.log"

qemu-system-i386 -m "${MEMSIZE}M" -cpu pentium3 -M pc \
  -kernel "$BZIMAGE" -append "root=/dev/sda rw console=ttyS0 panic=-1" \
  -drive file="$ROOTFS",format=raw,if=ide \
  -netdev user,id=n0,hostfwd=tcp::${SSHPORT}-:22 \
  -device e1000,netdev=n0 \
  -nographic -no-reboot > "$LOG" 2>&1 &
QPID=$!
trap 'kill "$QPID" 2>/dev/null' EXIT

echo "[qemu] booting (pid $QPID), waiting for sshd…"
up=0
for i in $(seq 1 60); do
  if [ -n "$SSHPASS_BIN" ]; then
    "$SSHPASS_BIN" -p thinkpad600x ssh $SSH_OPTS -p "$SSHPORT" root@127.0.0.1 'echo OK' 2>/dev/null | grep -q OK && { up=1; break; }
  else
    ssh $SSH_OPTS -p "$SSHPORT" root@127.0.0.1 'echo OK' 2>/dev/null | grep -q OK && { up=1; break; }
  fi
  sleep 2
done

if [ "$up" != 1 ]; then
  echo "[qemu] FAILED: sshd never came up"; tail -30 "$LOG"; exit 1
fi
echo "[qemu] sshd up after ~$((i*2))s"

run() {
  "$SSHPASS_BIN" -p thinkpad600x ssh $SSH_OPTS -p "$SSHPORT" root@127.0.0.1 "$@"
}

echo "=== uname ==="; run "uname -a"
echo "=== cpu ==="; run "grep -m1 'model name' /proc/cpuinfo"
echo "=== mem free ==="; run "free -m"
echo "=== hostname ==="; run "hostname"
echo "=== net ==="; run "ip -o addr show eth0"
echo "=== storage ==="; run "df -h /"
echo "=== wifi/bt modules present? ==="; run "find /lib/modules -name 'rt2800usb*' -o -name 'btusb*' -o -name 'thinkpad_acpi*' | sort"
echo "=== process count ==="; run "ps | wc -l"
echo "[qemu] DONE"
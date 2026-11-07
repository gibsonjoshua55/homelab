#!/bin/bash
# Boot a fresh Fedora CoreOS VM with the given Ignition config.
# Runs inside the tooling container; /work is the repo.
#   usage: run-vm <ignition-file>    (env: ARCH, STREAM, MEM, CPUS)
set -euo pipefail

IGN=${1:?usage: run-vm <ignition-file>}
ARCH=${ARCH:-$(uname -m)}
STREAM=${STREAM:-stable}
CACHE=/work/.cache/images/$ARCH
mkdir -p "$CACHE"

# Download (or reuse) the QEMU image for this stream/arch.
BASE=$(coreos-installer download -s "$STREAM" -p qemu -f qcow2.xz -a "$ARCH" \
         --decompress -C "$CACHE")
echo "Base image: $BASE"

# Fresh copy-on-write disk each run so Ignition runs as a first boot.
DISK=/work/.cache/disk-$ARCH.qcow2
rm -f "$DISK"
qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$DISK" 20G

case $ARCH in
  x86_64)  QEMU=(qemu-system-x86_64 -machine q35) ;;
  aarch64) QEMU=(qemu-system-aarch64 -machine virt
                 -bios /usr/share/edk2/aarch64/QEMU_EFI.fd) ;;
  *) echo "unsupported ARCH: $ARCH" >&2; exit 1 ;;
esac

echo "Booting $ARCH VM (software emulation; first boot takes a few minutes)."
echo "SSH: make ssh   |   quit console: Ctrl-A then X"
exec "${QEMU[@]}" \
  -cpu max -accel tcg,thread=multi -smp "${CPUS:-4}" -m "${MEM:-4096}" \
  -nographic \
  -drive if=virtio,file="$DISK" \
  -fw_cfg name=opt/com.coreos/config,file="$IGN" \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0

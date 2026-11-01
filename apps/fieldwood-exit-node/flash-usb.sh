#!/bin/bash
# Write build/nuc-install.iso to a USB stick, picked by its volume name.
# Runs on the Mac (not in the tools container) because it needs the real disk.
#   usage: flash-usb.sh [volume]    (env: VOLUME; prompts if neither is given)
set -euo pipefail

ISO=build/nuc-install.iso

die() { echo "error: $*" >&2; exit 1; }
# Read one key from `diskutil info -plist` (prints nothing if the key is missing).
info() { diskutil info -plist "$1" | plutil -extract "$2" raw -o - - 2>/dev/null || true; }

[[ $(uname -s) == Darwin ]] || die "this script only works on macOS"
[[ -f $ISO ]] || die "$ISO not found; build it first with: DEST_DEVICE=/dev/sda npx nx iso fieldwood-exit-node"

VOLUME=${1:-${VOLUME:-}}
if [[ -z $VOLUME ]]; then
  echo "External disks:"
  diskutil list external physical
  read -rp "USB volume name (as in /Volumes/<name>): " VOLUME
fi
# Accept "ESD-USB", "/Volumes/ESD-USB" or "/Volumes/ESD-USB/".
VOLUME=${VOLUME%/}
VOLUME=${VOLUME#/Volumes/}
MOUNT=/Volumes/$VOLUME
[[ -n $VOLUME && -d $MOUNT ]] || die "no volume mounted at $MOUNT"

DISK=$(info "$MOUNT" ParentWholeDisk)
[[ -n $DISK ]] || die "could not find the disk behind $MOUNT"

# Refuse anything that isn't a physical, external, removable disk.
[[ $(info "$DISK" VirtualOrPhysical) == Physical ]] \
  || die "$DISK is a virtual disk (APFS container?); reformat the stick as FAT32/ExFAT and retry"
[[ $(info "$DISK" Internal) == false ]] || die "$DISK is an internal disk"
[[ $(info "$DISK" Removable) == true || $(info "$DISK" RemovableMedia) == true \
   || $(info "$DISK" Ejectable) == true ]] || die "$DISK is not removable"

SIZE=$(info "$DISK" TotalSize)
NAME=$(info "$DISK" MediaName)
(( SIZE >= $(stat -f %z "$ISO") )) || die "$DISK is smaller than $ISO"

echo
diskutil list "/dev/$DISK"
echo "ISO:  $ISO ($(stat -f '%Sm' "$ISO"))"
echo "Disk: /dev/$DISK — $NAME, $(( SIZE / 1000000000 )) GB"
echo
echo "This ERASES everything on /dev/$DISK, including the $VOLUME volume."
read -rp "Type the volume name ($VOLUME) to continue: " CONFIRM
[[ $CONFIRM == "$VOLUME" ]] || die "confirmation did not match; nothing written"

diskutil unmountDisk "/dev/$DISK"
# rdiskN is the raw device: same disk, bypasses the buffer cache, much faster.
sudo dd if="$ISO" of="/dev/r$DISK" bs=4m status=progress
sync
diskutil eject "/dev/$DISK"
echo "Done. Plug the stick into the NUC and boot from it (F10 on most NUCs)."

#!/bin/bash

# Zero out a drive / disk and format it for use.
# Best run in sys-usb or whatever your equivalent is.
# The only required parameter is the path to the drive found through lsblk.

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

DEVICE=$1

if [ -z "$DEVICE" ]; then
  echo "Usage: sudo $0 <drive_path>"
  echo "Example: sudo $0 /dev/xvdi"
  exit 1
fi

if [ ! -b "$DEVICE" ]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

# Extract just the device name (e.g., "xvdi" from "/dev/xvdi")
BASENAME=$(basename "$DEVICE")

# Gather drive capabilities from sysfs
ROTATIONAL=$(cat "/sys/block/$BASENAME/queue/rotational" 2>/dev/null)
DISCARD_GRAN=$(cat "/sys/block/$BASENAME/queue/discard_granularity" 2>/dev/null)

# Print gathered info and warn the user
echo "==================== DRIVE INFO ===================="
echo "Target device: $DEVICE"

if [ "$ROTATIONAL" = "0" ]; then
    echo "Type: Solid State / Flash (Non-rotational)"
else
    echo "Type: Hard Disk Drive (Rotational)"
fi

if [ -n "$DISCARD_GRAN" ] && [ "$DISCARD_GRAN" -gt 0 ]; then
    echo "TRIM/DISCARD Support: YES"
else
    echo "TRIM/DISCARD Support: NO"
fi
echo "===================================================="

# Use lsblk to show the user the partitions before destroying them
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DEVICE"
echo ""

echo "WARNING: You are about to DESTROY ALL DATA on $DEVICE."
read -p "Type 'WIPE' to confirm: " confirm

if [ "$confirm" != "WIPE" ]; then
  echo "Aborted by user. No changes were made."
  exit 1
fi

echo "[*] Unmounting existing partitions..."
umount ${DEVICE}* 2>/dev/null

echo "[*] Wiping filesystem signatures..."
wipefs -a "$DEVICE"

# Determine the best wipe method based on our gathered info
if [ "$ROTATIONAL" = "0" ] && [ -n "$DISCARD_GRAN" ] && [ "$DISCARD_GRAN" -gt 0 ]; then
    echo "[*] Fast Flash Erasure: Using blkdiscard..."
    blkdiscard -f "$DEVICE"
else
    echo "[*] Zeroing Erasure: Using dd (this may take a long time)..."
    dd if=/dev/zero of="$DEVICE" bs=4M status=progress
fi

echo "[*] Creating new GPT partition table..."
parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart primary ext4 0% 100%

partprobe "$DEVICE"
sleep 2

if [[ "$DEVICE" =~ [0-9]$ ]]; then
    PARTITION="${DEVICE}p1"
else
    PARTITION="${DEVICE}1"
fi

echo "[*] Formatting $PARTITION to ext4..."
mkfs.ext4 -q "$PARTITION"

echo "[+] Success! $DEVICE is ready for use."
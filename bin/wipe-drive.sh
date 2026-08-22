#!/bin/bash

# Zero out a drive / disk and format it for use.
# Best run in sys-usb or whatever your equivalent is.
# The only required parameter is the `/dev` path to the drive.
# Use the `-q` flag if you want this to be a quick format.

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

# 1. Parse Arguments
QUICK_WIPE=0
DEVICE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -q|--quick)
            QUICK_WIPE=1
            shift
            ;;
        -*)
            echo "Error: Unknown option: $1"
            echo "Usage: sudo $0 [-q] <drive_path>"
            exit 1
            ;;
        *)
            DEVICE=$1
            shift
            ;;
    esac
done

# 2. Validate input
if [ -z "$DEVICE" ]; then
  echo "Usage: sudo $0 [-q] <drive_path>"
  echo "Example: sudo $0 -q /dev/xvdi"
  exit 1
fi

if [ ! -b "$DEVICE" ]; then
  echo "Error: $DEVICE is not a valid block device."
  exit 1
fi

BASENAME=$(basename "$DEVICE")
ROTATIONAL=$(cat "/sys/block/$BASENAME/queue/rotational" 2>/dev/null)
DISCARD_GRAN=$(cat "/sys/block/$BASENAME/queue/discard_granularity" 2>/dev/null)

# 3. Print Info and Confirm
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

lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DEVICE"
echo ""

if [ "$QUICK_WIPE" -eq 1 ]; then
    echo "WARNING: You are about to QUICK WIPE and format $DEVICE."
else
    echo "WARNING: You are about to COMPLETELY ZERO OUT and format $DEVICE."
fi

read -p "Type 'WIPE' to confirm: " confirm

if [ "$confirm" != "WIPE" ]; then
  echo "Aborted by user. No changes were made."
  exit 1
fi

# 4. Execute Unmount and Wipe
echo "[*] Unmounting existing partitions..."
umount ${DEVICE}* 2>/dev/null

echo "[*] Wiping filesystem signatures..."
wipefs -a "$DEVICE"

if [ "$QUICK_WIPE" -eq 1 ]; then
    echo "[*] Quick Wipe: Overwriting the first 100MB..."
    dd if=/dev/zero of="$DEVICE" bs=1M count=100 status=none
elif [ "$ROTATIONAL" = "0" ] && [ -n "$DISCARD_GRAN" ] && [ "$DISCARD_GRAN" -gt 0 ]; then
    echo "[*] Fast Flash Erasure: Using blkdiscard..."
    blkdiscard -f "$DEVICE"
else
    echo "[*] Zeroing Erasure: Using dd (this may take a long time)..."
    dd if=/dev/zero of="$DEVICE" bs=4M status=progress
fi

# 5. Format and Partition
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
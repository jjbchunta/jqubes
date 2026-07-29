#!/bin/bash

# Verify the integrity of the vm-pool after an improper system shutdown.

POOL="qubes_dom0/vm-pool"

notify-send "VM Pool Health Check" "Checking LVM Thin Pool Health for $POOL..."

# Attempt to query the logical volume. If the metadata is corrupted, 
# LVM commands typically throw an error and return a non-zero exit code.
if ! sudo lvdisplay "$POOL" > /dev/null 2>&1; then
    notify-send "VM Pool Health Check" "Thin pool is inaccessible. Metadata corruption may have occured."
    exit 1
else
    notify-send "VM Pool Health Check" "'$POOL' is accessible and functioning."
    META_USAGE=$(sudo lvs -o metadata_percent --noheadings "$POOL" | tr -d ' ')
    notify-send "VM Pool Health Check" "Current Metadata Usage: $META_USAGE%"
    exit 0
fi

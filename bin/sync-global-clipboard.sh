#!/bin/bash

# Read the global clipboard's buffer to dom0's clipboard.

if [ -f /run/qubes/qubes-clipboard.bin ]; then
    cat /run/qubes/qubes-clipboard.bin | xclip -selection clipboard
    notify-send "Global Clipboard" "Contents copied to dom0 clipboard."
else
    notify-send "Global Clipboard" "Global buffer is empty."
fi

#!/bin/bash

# When the Wi-Fi networks panel is only displaying "VPN Connections",
# restart both the system's net and firewall qube.

SYS_NET_QUBE=sys-net
SYS_FIREWALL_QUBE=sys-firewall

notify-send "Network Recovery" "Confirming Wi-Fi interface is operating..."

if ! qvm-check --running $SYS_NET_QUBE &> /dev/null; then
    notify-send "Network Recovery" "$SYS_NET_QUBE is not running. Exiting."
    exit 0
fi

# Query NetworkManager in sys-net for any recognized Wi-Fi interfaces
# We pipe stderr to /dev/null to keep things clean if the qube is unresponsive
WIFI_STATUS=$(qvm-run --pass-io $SYS_NET_QUBE "nmcli -t -f TYPE d 2>/dev/null" | grep -c "^wifi$")

if [ "$WIFI_STATUS" -eq 0 ]; then
    notify-send "Network Recovery" "Wi-Fi interface missing. Restarting $SYS_NET_QUBE and $SYS_FIREWALL_QUBE..."

    qvm-shutdown $SYS_NET_QUBE --force --wait && qvm-start $SYS_NET_QUBE

    # Arbitrary duration to ensure 
    wait 20

    qvm-shutdown $SYS_FIREWALL_QUBE --force --wait && qvm-start $SYS_FIREWALL_QUBE

    notify-send "Network Recovery" "Network qubes restarted successfully."
    exit 0
fi

notify-send "Network Recovery" "Network qubes operating as expected"

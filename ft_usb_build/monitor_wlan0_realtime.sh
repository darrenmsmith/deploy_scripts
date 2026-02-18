#!/bin/bash

################################################################################
# Monitor wlan0 Changes in Real-Time
# Watches for when wlan0 changes from IBSS to managed mode
# Run this DURING a service restart or in background during boot
################################################################################

OUTPUT_FILE="/tmp/wlan0_monitor_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/wlan0_monitor_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Real-Time wlan0 Monitor - $(hostname)"
echo "  Started: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Monitoring wlan0 for 120 seconds (2 minutes)..."
echo "Will capture when interface type changes"
echo ""

LAST_TYPE=""
LAST_SSID=""
LAST_STATE=""

for i in {1..120}; do
    TIMESTAMP=$(date +"%H:%M:%S")

    # Get current type
    CURRENT_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
    CURRENT_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')
    CURRENT_STATE=$(ip link show wlan0 2>/dev/null | grep -oP 'state \K\w+')

    # Detect changes
    if [ "$CURRENT_TYPE" != "$LAST_TYPE" ] || [ "$CURRENT_SSID" != "$LAST_SSID" ] || [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[$TIMESTAMP] CHANGE DETECTED!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Type:  $LAST_TYPE → $CURRENT_TYPE"
        echo "SSID:  $LAST_SSID → $CURRENT_SSID"
        echo "State: $LAST_STATE → $CURRENT_STATE"
        echo ""
        echo "Full interface info:"
        iw dev wlan0 info 2>/dev/null
        echo ""
        echo "Processes that might have caused this:"
        ps aux | grep -E "wpa|dhcp|network|iw|ip " | grep -v grep | grep -v monitor_wlan0
        echo ""
        echo "Recent systemd journal entries:"
        journalctl -n 10 --no-pager
        echo ""

        LAST_TYPE="$CURRENT_TYPE"
        LAST_SSID="$CURRENT_SSID"
        LAST_STATE="$CURRENT_STATE"
    fi

    # Show status every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        echo "[$TIMESTAMP] Status: Type=$CURRENT_TYPE, SSID=$CURRENT_SSID, State=$CURRENT_STATE"
    fi

    sleep 1
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Monitoring Complete"
echo "  Ended: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Final wlan0 state:"
iw dev wlan0 info
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

#!/bin/bash

################################################################################
# Check NetworkManager Configuration
# Find out if wlan0 is marked as unmanaged
################################################################################

OUTPUT_FILE="/tmp/networkmanager_config_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/networkmanager_config_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  NetworkManager Configuration - $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. NETWORKMANAGER MAIN CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/NetworkManager/NetworkManager.conf ==="
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    cat /etc/NetworkManager/NetworkManager.conf
else
    echo "File not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. NETWORKMANAGER CONF.D FILES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -d /etc/NetworkManager/conf.d ]; then
    ls -la /etc/NetworkManager/conf.d/
    echo ""
    for file in /etc/NetworkManager/conf.d/*; do
        if [ -f "$file" ]; then
            echo "--- $file ---"
            cat "$file"
            echo ""
        fi
    done
else
    echo "Directory not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. NETWORKMANAGER SYSTEM-CONNECTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -d /etc/NetworkManager/system-connections ]; then
    ls -la /etc/NetworkManager/system-connections/
    echo ""
    for file in /etc/NetworkManager/system-connections/*; do
        if [ -f "$file" ]; then
            echo "--- $file ---"
            cat "$file"
            echo ""
        fi
    done
else
    echo "Directory not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. NETWORKMANAGER DEVICE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== nmcli device status ==="
nmcli device status 2>/dev/null || echo "nmcli not available"
echo ""

echo "=== nmcli device show wlan0 ==="
nmcli device show wlan0 2>/dev/null || echo "wlan0 not found or nmcli not available"
echo ""

echo "=== nmcli general status ==="
nmcli general status 2>/dev/null || echo "nmcli not available"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. NETWORKMANAGER LOGS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
journalctl -u NetworkManager.service -b --no-pager | grep -i "wlan0" | tail -30
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  NetworkManager Configuration Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

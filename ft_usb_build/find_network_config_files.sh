#!/bin/bash

################################################################################
# Find ALL Network Configuration Files
# Identifies every file/service that could be managing wlan0
################################################################################

OUTPUT_FILE="/tmp/network_config_files_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/network_config_files_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Network Configuration Files - $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. WPA_SUPPLICANT CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/wpa_supplicant/wpa_supplicant.conf ==="
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
    cat /etc/wpa_supplicant/wpa_supplicant.conf
else
    echo "File not found"
fi
echo ""

echo "=== /etc/wpa_supplicant/wpa_supplicant-wlan0.conf ==="
if [ -f /etc/wpa_supplicant/wpa_supplicant-wlan0.conf ]; then
    cat /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
else
    echo "File not found"
fi
echo ""

echo "=== wpa_supplicant service status ==="
systemctl status wpa_supplicant.service --no-pager -l 2>&1 || echo "Not running as service"
echo ""
systemctl status wpa_supplicant@wlan0.service --no-pager -l 2>&1 || echo "Not running for wlan0"
echo ""

echo "=== wpa_supplicant processes ==="
ps aux | grep wpa_supplicant | grep -v grep || echo "No processes"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. NETWORK/INTERFACES CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/network/interfaces ==="
if [ -f /etc/network/interfaces ]; then
    cat /etc/network/interfaces
else
    echo "File not found"
fi
echo ""

echo "=== /etc/network/interfaces.d/ ==="
if [ -d /etc/network/interfaces.d ]; then
    ls -la /etc/network/interfaces.d/
    for file in /etc/network/interfaces.d/*; do
        if [ -f "$file" ]; then
            echo ""
            echo "--- $file ---"
            cat "$file"
        fi
    done
else
    echo "Directory not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. DHCPCD CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/dhcpcd.conf ==="
if [ -f /etc/dhcpcd.conf ]; then
    cat /etc/dhcpcd.conf | grep -v "^#" | grep -v "^$"
else
    echo "File not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. SYSTEMD-NETWORKD CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/systemd/network/ ==="
if [ -d /etc/systemd/network ]; then
    ls -la /etc/systemd/network/
    for file in /etc/systemd/network/*; do
        if [ -f "$file" ]; then
            echo ""
            echo "--- $file ---"
            cat "$file"
        fi
    done
else
    echo "Directory not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. UDEV RULES (NETWORK)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/udev/rules.d/ ==="
if [ -d /etc/udev/rules.d ]; then
    ls -la /etc/udev/rules.d/ | grep -i "net\|wlan"
    for file in /etc/udev/rules.d/*net* /etc/udev/rules.d/*wlan*; do
        if [ -f "$file" ]; then
            echo ""
            echo "--- $file ---"
            cat "$file"
        fi
    done 2>/dev/null
else
    echo "Directory not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. SYSTEMD SERVICES (NETWORK RELATED)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl list-units --type=service --state=active | grep -i "network\|wlan\|dhcp\|wpa"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. RASPBERRY PI SPECIFIC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== raspi-config settings ==="
if command -v raspi-config >/dev/null; then
    raspi-config nonint get_wifi_country || echo "Cannot get wifi country"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. CURRENT wlan0 STATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "iw dev wlan0 info:"
iw dev wlan0 info
echo ""
echo "iwconfig wlan0:"
iwconfig wlan0 2>/dev/null
echo ""
echo "ip link show wlan0:"
ip link show wlan0
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. PROCESSES THAT MIGHT MANAGE wlan0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ps aux | grep -E "wpa|dhcp|network|wlan" | grep -v grep
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Configuration Files Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

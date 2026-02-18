#!/bin/bash

################################################################################
# Check for Network Management Interference
# Identifies what might be changing wlan0 back to managed mode
################################################################################

OUTPUT_FILE="/tmp/network_interference_check_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/network_interference_check_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Network Management Interference Check - $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. NETWORKMANAGER STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl status NetworkManager.service --no-pager -l || echo "NetworkManager not installed/running"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. DHCPCD STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl status dhcpcd.service --no-pager -l || echo "dhcpcd not running as service"
ps aux | grep -i dhcpcd | grep -v grep
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. WPA_SUPPLICANT STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl status wpa_supplicant.service --no-pager -l || echo "wpa_supplicant not running as service"
ps aux | grep -i wpa_supplicant | grep -v grep
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. SYSTEMD-NETWORKD STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl status systemd-networkd.service --no-pager -l || echo "systemd-networkd not running"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. SERVICES MANAGING wlan0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NetworkManager devices:"
nmcli device 2>/dev/null || echo "nmcli not available"
echo ""
echo "dhcpcd configuration:"
cat /etc/dhcpcd.conf 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "No dhcpcd.conf"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. RECENT SYSTEMD LOGS (wlan0 related)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
journalctl -b --no-pager | grep -i "wlan0" | tail -50
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. KERNEL MESSAGES (wlan0 link changes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
dmesg | grep -i "wlan0.*link\|wlan0.*carrier\|wlan0.*up\|wlan0.*down" | tail -30
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Check Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

#!/bin/bash

################################################################################
# Full Device Comparison Diagnostic
# Run this on Device3 (Dev) and Device4 (Prod) for side-by-side comparison
################################################################################

OUTPUT_FILE="/tmp/full_device_diagnostic_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

# If USB is mounted, save there
if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/full_device_diagnostic_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Full Device Diagnostic - $(hostname)"
echo "  Date: $(date)"
echo "  Uptime: $(uptime -p)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. COMPLETE STARTUP SCRIPT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat /usr/local/bin/start-batman-mesh-client.sh 2>/dev/null || echo "Script not found"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. RF-KILL STATUS (DETAILED)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
rfkill list
echo ""
echo "RF-kill by ID:"
for i in 0 1 2; do
    echo "ID $i:"
    rfkill list $i 2>/dev/null || echo "  Not present"
done
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. WIRELESS INTERFACES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All wireless devices:"
iw dev
echo ""
echo "wlan0 detailed info:"
iw dev wlan0 info
echo ""
echo "wlan0 link status:"
ip link show wlan0
echo ""
echo "iwconfig wlan0:"
iwconfig wlan0 2>/dev/null || echo "iwconfig not available"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. IBSS PEER VISIBILITY (WiFi Layer)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "IBSS stations that wlan0 can see:"
iw dev wlan0 station dump
echo ""
echo "IBSS scan results:"
sudo iw dev wlan0 scan | grep -A 10 "IBSS\|ft_mesh" || echo "No IBSS networks found"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. BATMAN-ADV STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Batman-adv interfaces:"
sudo batctl if
echo ""
echo "Batman-adv neighbors:"
sudo batctl n
echo ""
echo "Batman-adv originators:"
sudo batctl o
echo ""
echo "Batman-adv gateway list:"
sudo batctl gwl
echo ""
echo "bat0 interface status:"
ip addr show bat0
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. CONNECTIVITY TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Can ping Device0 gateway:"
ping -c 3 -W 2 192.168.99.100 || echo "Cannot reach gateway"
echo ""
echo "Route to gateway:"
ip route get 192.168.99.100 || echo "No route"
echo ""
echo "ARP table:"
ip neigh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. SERVICE STATUS AND LOGS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Service status:"
systemctl status batman-mesh-client.service --no-pager -l
echo ""
echo "Service logs from this boot:"
journalctl -u batman-mesh-client.service -b --no-pager
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. KERNEL MESSAGES (MESH/WLAN/RFKILL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
dmesg | grep -i "wlan0\|batman\|mesh\|rfkill" | tail -50
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. HARDWARE INFO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Wireless hardware:"
lsusb | grep -i "wireless\|wifi\|802.11\|realtek\|ralink\|atheros" || echo "No USB WiFi found"
echo ""
echo "PCI wireless:"
lspci | grep -i "wireless\|wifi\|802.11" || echo "No PCI WiFi found"
echo ""
echo "Wireless drivers loaded:"
lsmod | grep -i "wlan\|wifi\|80211\|brcm\|rtl"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. TIMING INFORMATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "System uptime:"
uptime
echo ""
echo "When service started:"
systemctl show batman-mesh-client.service -p ActiveEnterTimestamp
echo ""
echo "How long ago was boot:"
who -b
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Diagnostic Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

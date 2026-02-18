#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "  Quick Mesh Check - $(hostname)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "1. RF-kill status:"
rfkill list
echo ""

echo "2. wlan0 interface status:"
ip link show wlan0
echo ""

echo "3. wlan0 wireless info:"
iw dev wlan0 info
echo ""

echo "4. iwconfig wlan0:"
iwconfig wlan0 2>/dev/null || echo "iwconfig not available"
echo ""

echo "5. Batman-adv interfaces:"
sudo batctl if
echo ""

echo "6. Startup script - key lines:"
echo "--- modprobe and rfkill section ---"
grep -A 10 "modprobe batman-adv" /usr/local/bin/start-batman-mesh-client.sh
echo ""

echo "7. Service logs from this boot:"
journalctl -u batman-mesh-client.service -b --no-pager -n 50
echo ""

echo "8. dmesg - recent wlan/batman messages:"
dmesg | grep -i "wlan0\|batman\|rfkill" | tail -30
echo ""

#!/bin/bash

################################################################################
# Disable WiFi in NetworkManager
# This is how Device5 (working) is configured
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Disable WiFi in NetworkManager - Device5 Method"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Current NetworkManager WiFi status:"
nmcli radio wifi
echo ""

echo "Current device status:"
nmcli device status
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Disabling WiFi in NetworkManager..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo nmcli radio wifi off

sleep 2

echo ""
echo "WiFi disabled. Checking status:"
nmcli radio wifi
echo ""

echo "Device status:"
nmcli device status
echo ""

echo "wlan0 should now show 'unavailable' like Device5"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Testing Mesh Service"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Restarting mesh service to test..."
sudo systemctl restart batman-mesh-client.service

sleep 5

echo ""
echo "Checking wlan0 status after service restart:"
iw dev wlan0 info | grep -E "type|ssid"
echo ""

echo "Checking batman neighbors:"
sudo batctl n
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "WiFi is now disabled in NetworkManager (like Device5)"
echo ""
echo "To test, reboot the device:"
echo "  sudo reboot"
echo ""
echo "After reboot, wlan0 should:"
echo "  • Stay in IBSS mode"
echo "  • Show as 'unavailable' in nmcli device status"
echo "  • Connect to mesh network"
echo "  • Show neighbors in: sudo batctl n"
echo ""

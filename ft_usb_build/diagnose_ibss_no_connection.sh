#!/bin/bash

################################################################################
# Diagnose IBSS Mode Set But No Mesh Connection
# Device is in IBSS mode but batctl n shows no neighbors
################################################################################

OUTPUT_FILE="/tmp/ibss_no_connection_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/ibss_no_connection_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Diagnose IBSS No Connection - $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. WLAN0 INTERFACE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== ip link show wlan0 ==="
ip link show wlan0
echo ""
echo "CRITICAL: Check if state is UP and if it has carrier"
echo ""

echo "=== iw dev wlan0 info ==="
iw dev wlan0 info
echo ""
echo "CRITICAL: Verify type is IBSS and SSID is ft_mesh2"
echo ""

echo "=== iw dev wlan0 link ==="
iw dev wlan0 link
echo ""
echo "CRITICAL: Check if connected to IBSS network"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. IBSS STATION VISIBILITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== iw dev wlan0 station dump ==="
iw dev wlan0 station dump
echo ""
echo "CRITICAL: Should show Device0 and Device5 if WiFi layer is working"
echo "If empty, wlan0 is not seeing ANY other devices at WiFi layer"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. BATMAN-ADV INTERFACE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== batctl if ==="
batctl if
echo ""
echo "CRITICAL: Check if wlan0 is 'active' or 'inactive'"
echo "If 'inactive', batman-adv hasn't activated the interface"
echo ""

echo "=== batctl n ==="
batctl n
echo ""
echo "CRITICAL: Should show Device0 if mesh is working"
echo ""

echo "=== batctl o ==="
batctl o
echo ""
echo "Shows originator table (mesh routes)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. BAT0 INTERFACE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== ip link show bat0 ==="
ip link show bat0 2>/dev/null || echo "bat0 interface not found!"
echo ""

echo "=== ip addr show bat0 ==="
ip addr show bat0 2>/dev/null || echo "bat0 interface not found!"
echo ""
echo "CRITICAL: Verify bat0 has IP address 10.0.0.X"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. MESH SERVICE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== systemctl status batman-mesh-client.service ==="
systemctl status batman-mesh-client.service --no-pager
echo ""

echo "=== journalctl -u batman-mesh-client.service -b ==="
journalctl -u batman-mesh-client.service -b --no-pager
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. RF-KILL STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== rfkill list ==="
rfkill list
echo ""
echo "CRITICAL: phy0 should NOT be soft or hard blocked"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. NETWORKMANAGER STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== nmcli device status ==="
nmcli device status 2>/dev/null || echo "nmcli not available"
echo ""
echo "CRITICAL: wlan0 should show 'unmanaged'"
echo ""

echo "=== NetworkManager unmanaged config ==="
if [ -f /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf ]; then
    cat /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf
else
    echo "Config file NOT found - NetworkManager might be managing wlan0!"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. PING TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== Ping Device0 at 10.0.0.1 ==="
ping -c 3 -W 2 10.0.0.1 2>&1 || echo "Cannot reach Device0"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. KERNEL MESSAGES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== dmesg | grep -E 'wlan0|batman|B.A.T.M.A.N' | tail -40 ==="
dmesg | grep -E 'wlan0|batman|B.A.T.M.A.N' | tail -40
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. RUNNING PROCESSES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== Processes that might interfere ==="
ps aux | grep -E "wpa|dhcp|NetworkManager" | grep -v grep
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  ANALYSIS SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo ""

# Quick analysis
echo "Quick Status Check:"
echo ""

# Check wlan0 state
WLAN0_STATE=$(ip link show wlan0 2>/dev/null | grep -oP 'state \K\w+')
echo "• wlan0 state: $WLAN0_STATE"
if [ "$WLAN0_STATE" != "UP" ]; then
    echo "  ❌ PROBLEM: wlan0 is not UP!"
fi

# Check wlan0 type
WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
echo "• wlan0 type: $WLAN0_TYPE"
if [ "$WLAN0_TYPE" != "IBSS" ]; then
    echo "  ❌ PROBLEM: wlan0 is not in IBSS mode!"
fi

# Check wlan0 SSID
WLAN0_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')
echo "• wlan0 SSID: $WLAN0_SSID"
if [ "$WLAN0_SSID" != "ft_mesh2" ]; then
    echo "  ❌ PROBLEM: wlan0 SSID is not ft_mesh2!"
fi

# Check batctl if
BATCTL_IF=$(batctl if 2>/dev/null | grep wlan0)
echo "• batctl if: $BATCTL_IF"
if echo "$BATCTL_IF" | grep -q "inactive"; then
    echo "  ❌ PROBLEM: wlan0 is inactive in batman-adv!"
fi

# Check if we can see any stations
STATION_COUNT=$(iw dev wlan0 station dump 2>/dev/null | grep -c "^Station")
echo "• WiFi stations visible: $STATION_COUNT"
if [ "$STATION_COUNT" -eq 0 ]; then
    echo "  ❌ PROBLEM: Cannot see ANY other devices at WiFi layer!"
    echo "     This means the IBSS network is not forming or Device0 is not visible"
fi

# Check neighbor count
NEIGHBOR_COUNT=$(batctl n 2>/dev/null | grep -c "^\[")
echo "• BATMAN neighbors: $NEIGHBOR_COUNT"
if [ "$NEIGHBOR_COUNT" -eq 0 ]; then
    echo "  ❌ PROBLEM: No mesh neighbors visible!"
fi

# Check RF-kill
if rfkill list | grep -A 1 "phy0" | grep -q "Soft blocked: yes"; then
    echo "• RF-kill: BLOCKED ❌"
    echo "  ❌ PROBLEM: phy0 is soft-blocked!"
else
    echo "• RF-kill: Unblocked ✓"
fi

# Check NetworkManager
NM_STATUS=$(nmcli device status 2>/dev/null | grep wlan0 | awk '{print $3}')
echo "• NetworkManager wlan0: $NM_STATUS"
if [ "$NM_STATUS" != "unmanaged" ]; then
    echo "  ⚠️  WARNING: wlan0 is not unmanaged by NetworkManager!"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Diagnostic Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

#!/bin/bash

################################################################################
# Check Client Mesh Configuration
# Run this on a client device to check its mesh configuration
################################################################################

echo "========================================"
echo "Client Mesh Configuration Check"
echo "========================================"
echo ""
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo ""

################################################################################
# 1. Service Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if systemctl is-enabled batman-mesh-client.service &>/dev/null; then
    echo "✓ Service is ENABLED (will start on boot)"
else
    echo "✗ Service is NOT ENABLED"
    echo "  Fix: sudo systemctl enable batman-mesh-client"
fi

if systemctl is-active batman-mesh-client.service &>/dev/null; then
    echo "✓ Service is ACTIVE (currently running)"
else
    echo "✗ Service is NOT ACTIVE"
    echo "  Fix: sudo systemctl start batman-mesh-client"
fi

echo ""

################################################################################
# 2. Configuration from Startup Script
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Configuration from Startup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "Startup script EXISTS"
    echo ""

    CLIENT_SSID=$(grep "^MESH_SSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
    CLIENT_FREQ=$(grep "^MESH_FREQ=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
    CLIENT_BSSID=$(grep "^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)

    echo "MESH_SSID=\"$CLIENT_SSID\""
    echo "MESH_FREQ=\"$CLIENT_FREQ\""
    echo "MESH_BSSID=\"$CLIENT_BSSID\""
else
    echo "✗ Startup script MISSING"
    echo "  Expected: /usr/local/bin/start-batman-mesh-client.sh"
    echo "  This means Phase 4 didn't complete successfully"
    exit 1
fi

echo ""

################################################################################
# 3. Current wlan0 Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Current wlan0 Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ip link show wlan0 &>/dev/null; then
    WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
    echo "wlan0 State: $WLAN0_STATE"

    if iw dev wlan0 info | grep -q "type IBSS"; then
        echo "✓ wlan0 Mode: IBSS (Ad-hoc)"

        CURRENT_SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
        echo "  Current SSID: $CURRENT_SSID"

        if [ "$CURRENT_SSID" = "$CLIENT_SSID" ]; then
            echo "  ✓ SSID matches configuration"
        else
            echo "  ✗ SSID MISMATCH!"
            echo "    Configured: $CLIENT_SSID"
            echo "    Actual: $CURRENT_SSID"
        fi
    else
        echo "✗ wlan0 Mode: NOT IBSS"
        CURRENT_MODE=$(iw dev wlan0 info | grep type | awk '{print $2}')
        echo "  Current mode: $CURRENT_MODE"
        echo "  This means the mesh network didn't start properly"
    fi
else
    echo "✗ wlan0 interface NOT FOUND"
fi

echo ""

################################################################################
# 4. bat0 Interface Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. bat0 Interface Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ip link show bat0 &>/dev/null; then
    echo "✓ bat0 interface EXISTS"

    BAT0_IP=$(ip addr show bat0 | grep 'inet ' | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo "✓ bat0 IP: $BAT0_IP"
    else
        echo "✗ bat0 has NO IP address"
    fi
else
    echo "✗ bat0 interface MISSING"
    echo "  This means batman-adv is not active"
fi

echo ""

################################################################################
# 5. BATMAN-adv Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. BATMAN-adv Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if lsmod | grep -q batman_adv; then
    echo "✓ batman-adv module LOADED"
else
    echo "✗ batman-adv module NOT loaded"
    echo "  Fix: sudo modprobe batman-adv"
fi

echo ""
echo "batctl interfaces:"
sudo batctl if 2>&1 || echo "  ERROR: batctl command failed"

echo ""
echo "batctl neighbors:"
sudo batctl n 2>&1 || echo "  ERROR: batctl command failed"

NEIGHBOR_COUNT=$(sudo batctl n 2>/dev/null | grep -v "Neighbor" | grep -v "^$" | wc -l)
if [ "$NEIGHBOR_COUNT" -gt 0 ]; then
    echo ""
    echo "✓ Found $NEIGHBOR_COUNT neighbor(s) - MESH IS WORKING!"
else
    echo ""
    echo "✗ NO NEIGHBORS FOUND"
    echo "  This is the problem - client can't see Device0"
fi

echo ""

################################################################################
# 6. Connectivity Test
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Connectivity Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEVICE0_IP="192.168.99.100"
echo "Testing ping to Device0 ($DEVICE0_IP)..."

if ping -c 3 -W 5 $DEVICE0_IP &>/dev/null; then
    echo "✓ Can reach Device0!"
else
    echo "✗ Cannot reach Device0"
    echo "  This confirms the mesh connection is not working"
fi

echo ""

################################################################################
# 7. Recent Service Logs
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Recent Service Logs (last 20 lines)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo journalctl -u batman-mesh-client -n 20 --no-pager 2>&1

echo ""

################################################################################
# Summary
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Configuration to verify against Device0:"
echo ""
echo "  MESH_SSID=\"$CLIENT_SSID\""
echo "  MESH_FREQ=\"$CLIENT_FREQ\""
echo "  MESH_BSSID=\"$CLIENT_BSSID\""
echo ""
echo "These MUST match Device0 exactly."
echo ""
echo "Quick Fixes:"
echo ""

if ! systemctl is-enabled batman-mesh-client.service &>/dev/null; then
    echo "1. Enable service:"
    echo "   sudo systemctl enable batman-mesh-client"
    echo ""
fi

if ! systemctl is-active batman-mesh-client.service &>/dev/null; then
    echo "2. Start service:"
    echo "   sudo systemctl start batman-mesh-client"
    echo ""
fi

if [ "$NEIGHBOR_COUNT" -eq 0 ]; then
    echo "3. Check if configuration matches Device0:"
    echo "   - Run get_device0_mesh_config.sh on Device0"
    echo "   - Compare SSID, FREQ, BSSID values"
    echo "   - Edit /usr/local/bin/start-batman-mesh-client.sh if needed"
    echo "   - Restart service: sudo systemctl restart batman-mesh-client"
    echo ""
fi

echo "For detailed diagnostics, run:"
echo "  sudo /tmp/capture_client_mesh_status.sh"
echo ""

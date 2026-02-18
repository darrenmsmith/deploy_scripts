#!/bin/bash

################################################################################
# Show Client Startup Script Contents
# Run on CLIENT to see what the startup script actually contains
################################################################################

echo "========================================"
echo "Client Startup Script Contents"
echo "========================================"
echo ""
echo "Device: $(hostname)"
echo ""

if [ ! -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "✗ ERROR: Startup script not found!"
    echo "  Expected: /usr/local/bin/start-batman-mesh-client.sh"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuration Variables"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

grep -E "^MESH_SSID=|^MESH_FREQ=|^MESH_BSSID=|^DEVICE_IP=" /usr/local/bin/start-batman-mesh-client.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IBSS Join Command"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

grep "iw dev.*ibss join" /usr/local/bin/start-batman-mesh-client.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Expected vs Actual"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MESH_SSID=$(grep "^MESH_SSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_FREQ=$(grep "^MESH_FREQ=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_BSSID=$(grep "^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)

echo "Current Configuration:"
echo "  MESH_SSID  = $MESH_SSID"
echo "  MESH_FREQ  = $MESH_FREQ"
echo "  MESH_BSSID = $MESH_BSSID"
echo ""

echo "Expected for Device0 Prod:"
echo "  MESH_SSID  = ft_mesh2"
echo "  MESH_FREQ  = 2412"
echo "  MESH_BSSID = b8:27:eb:3e:4a:99"
echo ""

# Check each value
ALL_CORRECT=true

if [ "$MESH_SSID" != "ft_mesh2" ]; then
    echo "✗ SSID MISMATCH!"
    ALL_CORRECT=false
else
    echo "✓ SSID correct"
fi

if [ "$MESH_FREQ" != "2412" ]; then
    echo "✗ FREQUENCY MISMATCH!"
    ALL_CORRECT=false
else
    echo "✓ Frequency correct"
fi

if [ "$MESH_BSSID" != "b8:27:eb:3e:4a:99" ]; then
    echo "✗ BSSID MISMATCH! ← THIS IS THE PROBLEM!"
    ALL_CORRECT=false
else
    echo "✓ BSSID correct"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Full Script Contents"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat -n /usr/local/bin/start-batman-mesh-client.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ALL_CORRECT" = true ]; then
    echo "✓ Configuration looks correct!"
    echo ""
    echo "If mesh still not connecting, try:"
    echo "  1. Run manual_mesh_test.sh to test step by step"
    echo "  2. Check Device0 is actually running: ssh pi@192.168.99.100 'iw dev wlan0 info'"
    echo "  3. Restart service: sudo systemctl restart batman-mesh-client"
else
    echo "✗ Configuration has errors - run fix_client_bssid.sh to fix"
fi

echo ""

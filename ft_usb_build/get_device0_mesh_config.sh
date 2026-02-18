#!/bin/bash

################################################################################
# Get Device0 Mesh Configuration
# Run this on Device0 to get the mesh parameters that clients must match
################################################################################

echo "========================================"
echo "Device0 Mesh Configuration"
echo "========================================"
echo ""
echo "Run this on Device0 Prod to get the mesh parameters."
echo "Clients must match these values EXACTLY."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "From wlan0 Interface"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get SSID from wlan0
SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
echo "SSID: $SSID"

# Get BSSID (MAC address)
BSSID=$(iw dev wlan0 info | grep "addr" | head -1 | awk '{print $2}')
echo "BSSID: $BSSID"

# Get frequency
FREQ=$(iw dev wlan0 info | grep "channel" | awk '{print $5}')
echo "Frequency: $FREQ MHz"

# Get channel
CHANNEL=$(iw dev wlan0 info | grep "channel" | awk '{print $2}')
echo "Channel: $CHANNEL"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "From Startup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    grep -E "MESH_SSID|MESH_BSSID|MESH_FREQ" /usr/local/bin/start-batman-mesh.sh | grep -v "^#"
else
    echo "Warning: /usr/local/bin/start-batman-mesh.sh not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Full wlan0 Info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
iw dev wlan0 info

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLIENT CONFIGURATION REQUIREMENTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Clients must have in their /usr/local/bin/start-batman-mesh-client.sh:"
echo ""
echo "MESH_SSID=\"$SSID\""
echo "MESH_FREQ=\"$FREQ\""
echo "MESH_BSSID=\"$BSSID\""
echo ""
echo "Copy these values and check them against the client configuration."
echo ""

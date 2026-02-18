#!/bin/bash

################################################################################
# Fix Client BSSID to Match Device0
# Run this on a client device to update mesh configuration
################################################################################

echo "========================================"
echo "Client Mesh BSSID Fix"
echo "========================================"
echo ""
echo "This script will update the client mesh configuration to match Device0."
echo ""

# Check if running on client
HOSTNAME=$(hostname)
if [[ ! $HOSTNAME =~ Device([1-5]) ]]; then
    echo "✗ Error: Must run on a client device (Device1-5)"
    echo "  Current hostname: $HOSTNAME"
    exit 1
fi

echo "Device: $HOSTNAME"
echo ""

# Check if startup script exists
if [ ! -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "✗ Error: Startup script not found"
    echo "  Expected: /usr/local/bin/start-batman-mesh-client.sh"
    echo "  Please run Phase 4 first"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CURRENT_SSID=$(grep "^MESH_SSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
CURRENT_FREQ=$(grep "^MESH_FREQ=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
CURRENT_BSSID=$(grep "^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)

echo "Current MESH_SSID:  $CURRENT_SSID"
echo "Current MESH_FREQ:  $CURRENT_FREQ"
echo "Current MESH_BSSID: $CURRENT_BSSID"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "New Configuration (Device0 Actual)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

NEW_SSID="ft_mesh2"
NEW_FREQ="2412"
NEW_BSSID="b8:27:eb:3e:4a:99"

echo "New MESH_SSID:  $NEW_SSID"
echo "New MESH_FREQ:  $NEW_FREQ"
echo "New MESH_BSSID: $NEW_BSSID"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Updating Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Backup original script
sudo cp /usr/local/bin/start-batman-mesh-client.sh /usr/local/bin/start-batman-mesh-client.sh.backup
echo "✓ Backed up original script"

# Update values
sudo sed -i "s/^MESH_SSID=.*/MESH_SSID=\"${NEW_SSID}\"/" /usr/local/bin/start-batman-mesh-client.sh
sudo sed -i "s/^MESH_FREQ=.*/MESH_FREQ=\"${NEW_FREQ}\"/" /usr/local/bin/start-batman-mesh-client.sh
sudo sed -i "s/^MESH_BSSID=.*/MESH_BSSID=\"${NEW_BSSID}\"/" /usr/local/bin/start-batman-mesh-client.sh

echo "✓ Updated startup script"
echo ""

# Verify changes
echo "Verifying changes:"
grep -E "^MESH_SSID=|^MESH_FREQ=|^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Restarting Mesh Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo systemctl restart batman-mesh-client
echo "✓ Service restarted"
echo ""

echo "Waiting 10 seconds for mesh to connect..."
sleep 10
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check service status
if systemctl is-active batman-mesh-client &>/dev/null; then
    echo "✓ Service is ACTIVE"
else
    echo "✗ Service is NOT active"
    echo "  Check logs: sudo journalctl -u batman-mesh-client -n 20"
fi

# Check wlan0 mode
echo ""
echo "wlan0 status:"
iw dev wlan0 info | grep -E "type|ssid"

# Check bat0
echo ""
if ip link show bat0 &>/dev/null; then
    echo "✓ bat0 interface exists"
    BAT0_IP=$(ip addr show bat0 | grep 'inet ' | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo "  IP: $BAT0_IP"
    fi
else
    echo "✗ bat0 interface missing"
fi

# Check neighbors
echo ""
echo "Mesh neighbors:"
sudo batctl n

NEIGHBOR_COUNT=$(sudo batctl n 2>/dev/null | grep -v "Neighbor" | grep -v "^$" | wc -l)

echo ""
if [ "$NEIGHBOR_COUNT" -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓✓✓ SUCCESS! ✓✓✓"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Mesh connection established!"
    echo "Found $NEIGHBOR_COUNT neighbor(s)"
    echo ""
    echo "Testing connectivity to Device0..."
    if ping -c 3 192.168.99.100 &>/dev/null; then
        echo "✓ Can ping Device0!"
    else
        echo "⚠ Cannot ping Device0 yet (may take a moment)"
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠ No Neighbors Found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The configuration has been updated, but no neighbors are visible yet."
    echo ""
    echo "Things to check:"
    echo "  1. Is Device0 powered on and mesh active?"
    echo "  2. Wait another 10-20 seconds and check again: sudo batctl n"
    echo "  3. Check service logs: sudo journalctl -u batman-mesh-client -n 30"
    echo "  4. Verify wlan0 is in IBSS mode: iw dev wlan0 info"
fi

echo ""
echo "Configuration updated successfully!"
echo ""

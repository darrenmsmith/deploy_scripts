#!/bin/bash

################################################################################
# Manual Mesh Test for Device0 (Gateway)
# Run this on DEVICE0 to manually test mesh setup
################################################################################

echo "========================================"
echo "Device0 Manual Mesh Connection Test"
echo "========================================"
echo ""
echo "Device: $(hostname)"
echo "This will manually run each mesh setup step on Device0"
echo ""
read -p "Press Enter to continue..."
echo ""

################################################################################
# Step 1: Stop the service
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Stopping batman-mesh service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo systemctl stop batman-mesh.service
sleep 2
echo "✓ Service stopped"
echo ""

################################################################################
# Step 2: Clean up existing configuration
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Cleaning up existing configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Leave IBSS if joined
sudo iw dev wlan0 ibss leave 2>/dev/null
echo "✓ Left IBSS network (if was joined)"

# Remove wlan0 from batman-adv
sudo batctl if del wlan0 2>/dev/null
echo "✓ Removed wlan0 from batman-adv (if was added)"

# Flush IP from bat0
sudo ip addr flush dev bat0 2>/dev/null
echo "✓ Flushed bat0 IP (if existed)"

# Bring down bat0
sudo ip link set bat0 down 2>/dev/null
echo "✓ Brought down bat0 (if existed)"

# Bring down wlan0
sudo ip link set wlan0 down 2>/dev/null
echo "✓ Brought down wlan0"

sleep 2
echo ""

################################################################################
# Step 3: Load batman-adv module
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Loading batman-adv module"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo modprobe batman-adv
if lsmod | grep -q batman_adv; then
    echo "✓ batman-adv module loaded"
else
    echo "✗ FAILED to load batman-adv module"
    exit 1
fi
echo ""

################################################################################
# Step 4: Configure wlan0
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Configuring wlan0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Setting wlan0 to IBSS mode..."
sudo ip link set wlan0 down
sudo iw dev wlan0 set type ibss
echo "✓ Set to IBSS mode"

echo ""
echo "Bringing wlan0 up..."
sudo ip link set wlan0 up
sleep 2

WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
echo "✓ wlan0 state: $WLAN0_STATE"

# Get wlan0 MAC address
WLAN0_MAC=$(cat /sys/class/net/wlan0/address)
echo "  wlan0 MAC: $WLAN0_MAC"
echo ""

################################################################################
# Step 5: Configuration values
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "We'll use:"
echo "  MESH_SSID:  ft_mesh2"
echo "  MESH_FREQ:  2412"
echo "  MESH_BSSID: $WLAN0_MAC (wlan0 MAC address)"
echo ""

MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="$WLAN0_MAC"

read -p "Press Enter to continue..."
echo ""

################################################################################
# Step 6: Join IBSS network
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Joining IBSS mesh network"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Command: iw dev wlan0 ibss join \"$MESH_SSID\" $MESH_FREQ fixed-freq $MESH_BSSID"
echo ""

sudo iw dev wlan0 ibss join "$MESH_SSID" $MESH_FREQ fixed-freq $MESH_BSSID

if [ $? -eq 0 ]; then
    echo "✓ IBSS join command succeeded"
else
    echo "✗ IBSS join command FAILED"
    echo ""
    echo "Checking wlan0 status..."
    iw dev wlan0 info
    exit 1
fi

sleep 3
echo ""

echo "Verifying IBSS mode..."
iw dev wlan0 info
echo ""

if iw dev wlan0 info | grep -q "type IBSS"; then
    echo "✓ Confirmed in IBSS mode"
    CURRENT_SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
    CURRENT_BSSID=$(iw dev wlan0 info | head -6 | grep addr | awk '{print $2}')
    echo "  SSID: $CURRENT_SSID"
    echo "  BSSID: $CURRENT_BSSID"
    echo ""
    echo "IMPORTANT: Clients must use BSSID: $CURRENT_BSSID"
else
    echo "✗ NOT in IBSS mode!"
    exit 1
fi
echo ""

################################################################################
# Step 7: Add wlan0 to batman-adv
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Adding wlan0 to batman-adv"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Command: batctl if add wlan0"
sudo batctl if add wlan0

if [ $? -eq 0 ]; then
    echo "✓ wlan0 added to batman-adv"
else
    echo "✗ Failed to add wlan0 to batman-adv"
    exit 1
fi

sleep 2
echo ""

echo "Verifying batman-adv interfaces..."
sudo batctl if
echo ""

################################################################################
# Step 8: Configure bat0
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Bringing up bat0 interface"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Command: ip link set bat0 up"
sudo ip link set bat0 up

if [ $? -eq 0 ]; then
    echo "✓ bat0 interface up"
else
    echo "✗ Failed to bring up bat0"
    exit 1
fi

sleep 2
echo ""

################################################################################
# Step 9: Assign IP address
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 9: Assigning IP address to bat0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEVICE0_IP="192.168.99.100/24"
echo "Device0 IP: $DEVICE0_IP"
echo ""

echo "Command: ip addr add $DEVICE0_IP dev bat0"
sudo ip addr add $DEVICE0_IP dev bat0

if [ $? -eq 0 ]; then
    echo "✓ IP address assigned"
else
    # Check if already assigned
    if ip addr show bat0 | grep -q "192.168.99.100"; then
        echo "✓ IP address already assigned"
    else
        echo "✗ Failed to assign IP address"
    fi
fi

echo ""
ip addr show bat0
echo ""

################################################################################
# Step 10: Enable gateway mode
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Enabling gateway mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Command: batctl gw_mode server"
sudo batctl gw_mode server

echo ""
echo "Gateway mode:"
sudo batctl gw
echo ""

################################################################################
# Step 11: Wait and check for neighbors
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 11: Checking for mesh neighbors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Waiting 15 seconds for clients to connect..."
for i in {15..1}; do
    echo -n "$i... "
    sleep 1
done
echo ""
echo ""

echo "Checking neighbors..."
sudo batctl n
echo ""

NEIGHBOR_COUNT=$(sudo batctl n 2>/dev/null | grep wlan0 | wc -l)

if [ "$NEIGHBOR_COUNT" -gt 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓✓✓ SUCCESS! ✓✓✓"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Found $NEIGHBOR_COUNT neighbor(s)!"
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠ NO NEIGHBORS YET"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This is normal if no clients have connected yet."
    echo ""
    echo "Device0 mesh is now active and waiting for clients."
    echo ""
    echo "Client devices must use these values:"
    echo "  MESH_SSID:  $MESH_SSID"
    echo "  MESH_FREQ:  $MESH_FREQ"
    echo "  MESH_BSSID: $CURRENT_BSSID"
    echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Device0 Mesh Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "wlan0 info:"
iw dev wlan0 info | grep -E "type|ssid|channel|addr"
echo ""

echo "bat0 info:"
ip addr show bat0 | grep -E "state|inet"
echo ""

echo "batman-adv interfaces:"
sudo batctl if
echo ""

echo "Manual test complete!"
echo ""

#!/bin/bash

################################################################################
# Manual Mesh Test - Step by Step Execution
# Run this on a CLIENT device to manually test mesh connection
################################################################################

echo "========================================"
echo "Manual Mesh Connection Test"
echo "========================================"
echo ""
echo "Device: $(hostname)"
echo "This will manually run each mesh setup step to find the problem"
echo ""
read -p "Press Enter to continue..."
echo ""

################################################################################
# Step 1: Stop the service
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Stopping batman-mesh-client service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo systemctl stop batman-mesh-client.service
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
echo ""

################################################################################
# Step 5: Read configuration from startup script
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Reading configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "✗ ERROR: Startup script not found!"
    exit 1
fi

echo "Reading from: /usr/local/bin/start-batman-mesh-client.sh"
echo ""

# Extract configuration
MESH_SSID=$(grep "^MESH_SSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_FREQ=$(grep "^MESH_FREQ=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_BSSID=$(grep "^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)

echo "Configuration values:"
echo "  MESH_SSID:  $MESH_SSID"
echo "  MESH_FREQ:  $MESH_FREQ"
echo "  MESH_BSSID: $MESH_BSSID"
echo ""

# Validate
if [ -z "$MESH_SSID" ] || [ -z "$MESH_FREQ" ] || [ -z "$MESH_BSSID" ]; then
    echo "✗ ERROR: Configuration values are missing!"
    exit 1
fi

# Check if BSSID is the correct one
if [ "$MESH_BSSID" != "b8:27:eb:3e:4a:99" ]; then
    echo "⚠ WARNING: BSSID is not b8:27:eb:3e:4a:99"
    echo "  Current: $MESH_BSSID"
    echo "  Expected: b8:27:eb:3e:4a:99"
    echo ""
    echo "This will likely fail to connect!"
    echo ""
fi

echo "Also checking the actual join command in the script..."
echo ""
grep "iw dev.*ibss join" /usr/local/bin/start-batman-mesh-client.sh
echo ""
echo "Make sure this command uses the variables, not hardcoded values!"
echo ""

read -p "Press Enter to continue with these values..."
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
    echo "  SSID: $CURRENT_SSID"
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

HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}/24"
    echo "Device: Device${DEVICE_NUM}"
    echo "IP: $DEVICE_IP"
else
    echo "✗ Invalid hostname: $HOSTNAME"
    exit 1
fi

echo ""
echo "Command: ip addr add $DEVICE_IP dev bat0"
sudo ip addr add $DEVICE_IP dev bat0

if [ $? -eq 0 ]; then
    echo "✓ IP address assigned"
else
    # Check if already assigned
    if ip addr show bat0 | grep -q "$DEVICE_IP"; then
        echo "✓ IP address already assigned"
    else
        echo "✗ Failed to assign IP address"
    fi
fi

echo ""
ip addr show bat0
echo ""

################################################################################
# Step 10: Wait and check for neighbors
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 10: Checking for mesh neighbors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Waiting 15 seconds for mesh to form..."
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
    echo ""
    echo "Testing connectivity to Device0..."
    if ping -c 3 -W 5 192.168.99.100 &>/dev/null; then
        echo "✓ Can ping Device0!"
    else
        echo "⚠ Cannot ping Device0 yet (may take a moment)"
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ NO NEIGHBORS FOUND"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Troubleshooting information:"
    echo ""

    echo "1. wlan0 status:"
    iw dev wlan0 info
    echo ""

    echo "2. bat0 status:"
    ip addr show bat0
    echo ""

    echo "3. batctl interfaces:"
    sudo batctl if
    echo ""

    echo "4. Check Device0 is running and has same SSID:"
    echo "   On Device0: iw dev wlan0 info | grep ssid"
    echo "   Should match: $MESH_SSID"
    echo ""

    echo "5. Check Device0 BSSID:"
    echo "   On Device0: iw dev wlan0 info | grep addr"
    echo "   Should be: b8:27:eb:3e:4a:99"
    echo ""
fi

echo ""
echo "Manual test complete!"
echo ""

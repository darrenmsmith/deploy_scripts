#!/bin/bash

################################################################################
# Fix Client Mesh Startup - Ensure IBSS Mode Actually Works
# Adds verification and retry logic for IBSS mode change
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Fixing Client Mesh Startup - IBSS Mode Verification"
echo "════════════════════════════════════════════════════════════"
echo ""

STARTUP_SCRIPT="/usr/local/bin/start-batman-mesh-client.sh"

if [ ! -f "$STARTUP_SCRIPT" ]; then
    echo "✗ ERROR: Startup script not found: $STARTUP_SCRIPT"
    exit 1
fi

echo "Found startup script: $STARTUP_SCRIPT"
echo ""

# Create backup
BACKUP_FILE="${STARTUP_SCRIPT}.backup_ibss_$(date +%Y%m%d_%H%M%S)"
sudo cp "$STARTUP_SCRIPT" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Create new startup script with robust IBSS mode setting
echo "Creating new startup script with IBSS verification..."
echo ""

sudo tee "$STARTUP_SCRIPT" > /dev/null << 'EOF'
#!/bin/bash

# Field Trainer - Client Mesh Startup Script (WITH VERIFICATION)
# This version ensures IBSS mode actually gets set

MESH_IFACE="wlan0"
MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="b8:27:eb:3e:4a:99"
DEVICE_IP="192.168.99.104"

# Get actual device IP from hostname
HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}"
fi

echo "═══════════════════════════════════════════════════════"
echo "Starting BATMAN mesh - $(hostname) - $DEVICE_IP"
echo "═══════════════════════════════════════════════════════"

# Load batman-adv module
echo "Loading batman-adv module..."
modprobe batman-adv || { echo "ERROR: Failed to load batman-adv"; exit 1; }

# ROBUST RF-KILL UNBLOCK
echo "Unblocking RF-kill..."
rfkill unblock all
sleep 2
rfkill unblock 0 2>/dev/null || true
rfkill unblock wifi
sleep 1

# Verify RF-kill is unblocked
if rfkill list | grep -A 1 "phy0" | grep -q "Soft blocked: yes"; then
    echo "ERROR: phy0 still soft-blocked after unblock attempts!"
    rfkill list
    exit 1
fi
echo "✓ RF-kill unblocked"

# Bring down interface
echo "Bringing down ${MESH_IFACE}..."
ip link set ${MESH_IFACE} down || { echo "ERROR: Cannot bring down interface"; exit 1; }

# Set to IBSS mode with retry
echo "Setting ${MESH_IFACE} to IBSS mode..."
IBSS_SET=0
for attempt in 1 2 3; do
    echo "  Attempt $attempt to set IBSS mode..."
    iw dev ${MESH_IFACE} set type ibss 2>&1
    sleep 1

    # Verify it worked
    if iw dev ${MESH_IFACE} info | grep -q "type IBSS"; then
        echo "✓ IBSS mode set successfully"
        IBSS_SET=1
        break
    else
        echo "  Mode not set yet, retrying..."
        sleep 2
    fi
done

if [ $IBSS_SET -eq 0 ]; then
    echo "ERROR: Failed to set IBSS mode after 3 attempts!"
    echo "Current interface state:"
    iw dev ${MESH_IFACE} info
    exit 1
fi

# Bring interface up
echo "Bringing up ${MESH_IFACE}..."
ip link set ${MESH_IFACE} up || { echo "ERROR: Cannot bring up interface"; exit 1; }
sleep 2

# Verify interface is up
if ! ip link show ${MESH_IFACE} | grep -q "state UP"; then
    echo "WARNING: Interface not in UP state"
    ip link show ${MESH_IFACE}
fi

# Join IBSS network
echo "Joining IBSS network: ${MESH_SSID}..."
iw dev ${MESH_IFACE} ibss join ${MESH_SSID} ${MESH_FREQ} fixed-freq ${MESH_BSSID} || {
    echo "ERROR: Failed to join IBSS network"
    iw dev ${MESH_IFACE} info
    exit 1
}
sleep 3

# Verify we joined
CURRENT_SSID=$(iw dev ${MESH_IFACE} info | grep ssid | awk '{print $2}')
if [ "$CURRENT_SSID" != "$MESH_SSID" ]; then
    echo "ERROR: Did not join correct SSID! Got: $CURRENT_SSID, Expected: $MESH_SSID"
    iw dev ${MESH_IFACE} info
    exit 1
fi
echo "✓ Joined IBSS network: $CURRENT_SSID"

# Add interface to batman-adv
echo "Adding ${MESH_IFACE} to batman-adv..."
batctl if add ${MESH_IFACE} || { echo "ERROR: Cannot add to batman-adv"; exit 1; }
sleep 2

# Bring up bat0 interface
echo "Bringing up bat0..."
ip link set bat0 up || { echo "ERROR: Cannot bring up bat0"; exit 1; }
sleep 2

# Assign IP to bat0
echo "Assigning IP ${DEVICE_IP}/24 to bat0..."
ip addr add ${DEVICE_IP}/24 dev bat0 2>/dev/null || {
    # IP might already be assigned
    if ip addr show bat0 | grep -q "${DEVICE_IP}/24"; then
        echo "✓ IP already assigned (OK)"
    else
        echo "ERROR: Cannot assign IP"
        exit 1
    fi
}

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✓ BATMAN mesh started successfully!"
echo "═══════════════════════════════════════════════════════"
echo "Device: $(hostname)"
echo "Device IP: ${DEVICE_IP}"
echo "SSID: ${MESH_SSID}"
echo "BSSID: ${MESH_BSSID}"
echo ""
echo "Interface status:"
iw dev ${MESH_IFACE} info | grep -E "type|ssid"
echo ""
echo "Batman-adv interfaces:"
batctl if
echo ""
EOF

sudo chmod +x "$STARTUP_SCRIPT"

echo "✓ New startup script created with verification"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Verification"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "New script includes:"
echo "  ✓ Robust RF-kill unblock (unblock all + sleep + verify)"
echo "  ✓ IBSS mode setting with 3 retry attempts"
echo "  ✓ Verification that IBSS mode actually got set"
echo "  ✓ Verification that we joined correct SSID"
echo "  ✓ Error messages if anything fails"
echo "  ✓ Script will FAIL instead of silently continuing"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Fix complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "To test:"
echo "  sudo systemctl restart batman-mesh-client.service"
echo "  sudo journalctl -u batman-mesh-client.service -n 50"
echo ""
echo "Then test with reboot:"
echo "  sudo reboot"
echo ""
echo "After reboot, check:"
echo "  sudo journalctl -u batman-mesh-client.service -b"
echo "  iw dev wlan0 info | grep type    # Should show 'IBSS'"
echo "  sudo batctl n                     # Should show Device0"
echo ""

#!/bin/bash

################################################################################
# Manual Mesh Test for CLIENT - WITH LOGGING
# Run this on a CLIENT device to manually test mesh setup
################################################################################

# Output file - save to USB if mounted, otherwise /tmp
if [ -d "/mnt/usb/ft_usb_build" ]; then
    LOG_FILE="/mnt/usb/ft_usb_build/client_manual_test_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
else
    LOG_FILE="/tmp/client_manual_test_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

# Function to log and display
log_both() {
    echo "$@" | tee -a "$LOG_FILE"
}

log_both "========================================"
log_both "Client Manual Mesh Connection Test"
log_both "========================================"
log_both ""
log_both "Device: $(hostname)"
log_both "Date: $(date)"
log_both "Output saving to: $LOG_FILE"
log_both ""

# Stop the service
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 1: Stopping batman-mesh-client service"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo systemctl stop batman-mesh-client.service 2>&1 | tee -a "$LOG_FILE"
sleep 2
log_both "✓ Service stopped"
log_both ""

# Clean up
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 2: Cleaning up existing configuration"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo iw dev wlan0 ibss leave 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Left IBSS network"

sudo batctl if del wlan0 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Removed wlan0 from batman-adv"

sudo ip link set bat0 down 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Brought down bat0"

sudo ip link set wlan0 down 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Brought down wlan0"

sleep 2
log_both ""

# Load module
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 3: Loading batman-adv module"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo modprobe batman-adv 2>&1 | tee -a "$LOG_FILE"
lsmod | grep batman 2>&1 | tee -a "$LOG_FILE"
log_both "✓ batman-adv module loaded"
log_both ""

# Configure wlan0
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 4: Configuring wlan0"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo ip link set wlan0 down 2>&1 | tee -a "$LOG_FILE"
sudo iw dev wlan0 set type ibss 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Set to IBSS mode"

# Unblock RF-kill if blocked
log_both "Checking RF-kill status..."
sudo rfkill unblock wifi 2>&1 | tee -a "$LOG_FILE"
log_both "✓ RF-kill unblocked"

sudo ip link set wlan0 up 2>&1 | tee -a "$LOG_FILE"
sleep 2

WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
log_both "✓ wlan0 state: $WLAN0_STATE"
log_both ""

# Read configuration
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 5: Reading configuration from startup script"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

if [ ! -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    log_both "✗ ERROR: Startup script not found!"
    exit 1
fi

MESH_SSID=$(grep "^MESH_SSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_FREQ=$(grep "^MESH_FREQ=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)
MESH_BSSID=$(grep "^MESH_BSSID=" /usr/local/bin/start-batman-mesh-client.sh | cut -d'"' -f2)

log_both "Configuration from startup script:"
log_both "  MESH_SSID:  $MESH_SSID"
log_both "  MESH_FREQ:  $MESH_FREQ"
log_both "  MESH_BSSID: $MESH_BSSID"
log_both ""

log_both "Join command in script:"
grep "iw dev.*ibss join" /usr/local/bin/start-batman-mesh-client.sh 2>&1 | tee -a "$LOG_FILE"
log_both ""

if [ "$MESH_BSSID" != "b8:27:eb:3e:4a:99" ]; then
    log_both "⚠ WARNING: BSSID doesn't match Device0!"
    log_both "  Current:  $MESH_BSSID"
    log_both "  Expected: b8:27:eb:3e:4a:99"
    log_both ""
fi

# Join IBSS
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 6: Joining IBSS mesh network"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

log_both "Command: iw dev wlan0 ibss join \"$MESH_SSID\" $MESH_FREQ fixed-freq $MESH_BSSID"
sudo iw dev wlan0 ibss join "$MESH_SSID" $MESH_FREQ fixed-freq $MESH_BSSID 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_both "✓ IBSS join command succeeded"
else
    log_both "✗ IBSS join command FAILED"
    iw dev wlan0 info 2>&1 | tee -a "$LOG_FILE"
    exit 1
fi

sleep 3
log_both ""

log_both "Verifying IBSS mode:"
iw dev wlan0 info 2>&1 | tee -a "$LOG_FILE"
log_both ""

CURRENT_SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
log_both "  Current SSID: $CURRENT_SSID"
log_both ""

# Add to batman-adv
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 7: Adding wlan0 to batman-adv"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo batctl if add wlan0 2>&1 | tee -a "$LOG_FILE"
log_both "✓ wlan0 added to batman-adv"
sleep 2
log_both ""

sudo batctl if 2>&1 | tee -a "$LOG_FILE"
log_both ""

# Bring up bat0
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 8: Bringing up bat0 interface"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo ip link set bat0 up 2>&1 | tee -a "$LOG_FILE"
log_both "✓ bat0 interface up"
sleep 2
log_both ""

# Assign IP
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 9: Assigning IP address to bat0"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

HOSTNAME=$(hostname)
if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}/24"
    log_both "Device: Device${DEVICE_NUM}"
    log_both "IP: $DEVICE_IP"
else
    log_both "✗ Invalid hostname: $HOSTNAME"
    exit 1
fi

sudo ip addr add $DEVICE_IP dev bat0 2>&1 | tee -a "$LOG_FILE"
log_both "✓ IP address assigned"
log_both ""

ip addr show bat0 2>&1 | tee -a "$LOG_FILE"
log_both ""

# Check neighbors
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 10: Checking for mesh neighbors"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

log_both "Waiting 15 seconds for mesh to form..."
sleep 15
log_both ""

log_both "Checking neighbors:"
sudo batctl n 2>&1 | tee -a "$LOG_FILE"
log_both ""

NEIGHBOR_COUNT=$(sudo batctl n 2>/dev/null | grep wlan0 | wc -l)

if [ "$NEIGHBOR_COUNT" -gt 0 ]; then
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both "✓✓✓ SUCCESS! Found $NEIGHBOR_COUNT neighbor(s)! ✓✓✓"
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both ""
    log_both "Testing connectivity to Device0..."
    if ping -c 3 -W 5 192.168.99.100 2>&1 | tee -a "$LOG_FILE" | grep -q "3 received"; then
        log_both "✓ Can ping Device0!"
    else
        log_both "⚠ Cannot ping Device0"
    fi
else
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both "✗ NO NEIGHBORS FOUND"
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both ""
    log_both "Check:"
    log_both "1. Is Device0 mesh running?"
    log_both "2. Does BSSID match Device0? (should be b8:27:eb:3e:4a:99)"
    log_both "3. Does SSID match? (should be ft_mesh2)"
fi

log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Manual test complete!"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "Log saved to: $LOG_FILE"
log_both ""

echo ""
if [ -d "/mnt/usb/ft_usb_build" ]; then
    echo "Log file saved to USB drive - you can now unmount and move it back to Device0"
else
    echo "Copy this log file to USB drive or back to Device0:"
    echo "  scp $LOG_FILE pi@192.168.99.100:/mnt/usb/ft_usb_build/"
fi
echo ""

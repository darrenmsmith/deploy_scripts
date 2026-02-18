#!/bin/bash

################################################################################
# Manual Mesh Test for Device0 (Gateway) - WITH LOGGING
# Run this on DEVICE0 to manually test mesh setup
################################################################################

# Output file on USB drive
LOG_FILE="/mnt/usb/ft_usb_build/device0_manual_test_$(date +%Y%m%d_%H%M%S).log"

# Function to log and display
log_both() {
    echo "$@" | tee -a "$LOG_FILE"
}

log_both "========================================"
log_both "Device0 Manual Mesh Connection Test"
log_both "========================================"
log_both ""
log_both "Device: $(hostname)"
log_both "Date: $(date)"
log_both "Output saving to: $LOG_FILE"
log_both ""

# Stop the service
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 1: Stopping batman-mesh service"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo systemctl stop batman-mesh.service 2>&1 | tee -a "$LOG_FILE"
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

sudo ip addr flush dev bat0 2>&1 | tee -a "$LOG_FILE"
log_both "✓ Flushed bat0 IP"

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

WLAN0_MAC=$(cat /sys/class/net/wlan0/address)
log_both "  wlan0 MAC: $WLAN0_MAC"
log_both ""

# Configuration
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 5: Configuration"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

MESH_SSID="ft_mesh2"
MESH_FREQ="2412"
MESH_BSSID="$WLAN0_MAC"

log_both "Using values:"
log_both "  MESH_SSID:  $MESH_SSID"
log_both "  MESH_FREQ:  $MESH_FREQ"
log_both "  MESH_BSSID: $MESH_BSSID"
log_both ""

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
    exit 1
fi

sleep 3
log_both ""

log_both "Verifying IBSS mode:"
iw dev wlan0 info 2>&1 | tee -a "$LOG_FILE"
log_both ""

CURRENT_SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
CURRENT_BSSID=$(iw dev wlan0 info | head -6 | grep addr | awk '{print $2}')
log_both "  SSID: $CURRENT_SSID"
log_both "  BSSID: $CURRENT_BSSID"
log_both ""
log_both "⭐ IMPORTANT: Clients must use BSSID: $CURRENT_BSSID ⭐"
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

DEVICE0_IP="192.168.99.100/24"
sudo ip addr add $DEVICE0_IP dev bat0 2>&1 | tee -a "$LOG_FILE"
log_both "✓ IP address assigned: $DEVICE0_IP"
log_both ""

ip addr show bat0 2>&1 | tee -a "$LOG_FILE"
log_both ""

# Gateway mode
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 10: Enabling gateway mode"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

sudo batctl gw_mode server 2>&1 | tee -a "$LOG_FILE"
sudo batctl gw 2>&1 | tee -a "$LOG_FILE"
log_both ""

# Check neighbors
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Step 11: Checking for mesh neighbors"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""

log_both "Waiting 15 seconds for clients to connect..."
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
else
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both "⚠ NO NEIGHBORS YET"
    log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_both ""
    log_both "This is normal if no clients have connected yet."
    log_both "Device0 mesh is now active and waiting for clients."
    log_both ""
    log_both "Client devices must use:"
    log_both "  MESH_SSID:  $MESH_SSID"
    log_both "  MESH_FREQ:  $MESH_FREQ"
    log_both "  MESH_BSSID: $CURRENT_BSSID"
fi

log_both ""
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both "Manual test complete!"
log_both "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_both ""
log_both "Log saved to: $LOG_FILE"
log_both ""

echo ""
echo "You can now review the log file or copy it for analysis."
echo "Log file: $LOG_FILE"
echo ""

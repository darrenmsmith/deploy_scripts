#!/bin/bash

################################################################################
# Field Trainer - Client Phase 4: Mesh Network Join
# Join BATMAN-adv mesh network and connect to Device0
# Enhanced with detailed error logging and diagnostics
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

# Create log file for this phase
LOG_FILE="/tmp/phase4_mesh_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "$LOG_FILE")

echo "════════════════════════════════════════════════════════════"
echo "  Client Phase 4: Mesh Network Join"
echo "  Log file: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

################################################################################
# Step 1: Get Device Number
################################################################################

log_step "Step 1: Detecting device number from hostname"

HOSTNAME=$(hostname)
echo "Current hostname: $HOSTNAME"

if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    DEVICE_IP="192.168.99.10${DEVICE_NUM}"
    log_success "Device number: $DEVICE_NUM"
    log_success "Target IP: $DEVICE_IP"
else
    log_error "HOSTNAME VALIDATION FAILED"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "Current hostname: $HOSTNAME"
    echo "Expected pattern: Device1, Device2, Device3, Device4, or Device5"
    echo ""
    echo "═══ HOW TO FIX ═══"
    echo "Set correct hostname:"
    echo "  sudo hostnamectl set-hostname Device1"
    echo "  sudo reboot"
    echo ""
    echo "Or check hostname with: hostname"
    echo ""
    exit 1
fi

################################################################################
# Step 2: Mesh Network Configuration
################################################################################

log_step "Step 2: Mesh network configuration"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mesh Network Settings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The mesh network SSID must match Device0's configuration"
echo "Check Device0: sudo batctl if"
echo ""

read -p "Enter mesh SSID (default: ft_mesh): " MESH_SSID
MESH_SSID=${MESH_SSID:-ft_mesh}

read -p "Enter mesh channel (default: 1): " MESH_CHANNEL
MESH_CHANNEL=${MESH_CHANNEL:-1}

# BSSID must match Device0 (00:11:22:33:44:55 is standard)
MESH_BSSID="00:11:22:33:44:55"

log_success "Configuration entered:"
echo "  SSID: $MESH_SSID"
echo "  Channel: $MESH_CHANNEL"
echo "  BSSID: $MESH_BSSID"

# Calculate frequency from channel (2.4GHz)
MESH_FREQ=$((2407 + 5 * MESH_CHANNEL))
echo "  Frequency: ${MESH_FREQ} MHz"

################################################################################
# Step 3: Verify wlan0 Available
################################################################################

log_step "Step 3: Verifying wlan0 (onboard WiFi)"

if ip link show wlan0 &>/dev/null; then
    log_success "wlan0 interface exists"

    # Show current state
    WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
    echo "  Current state: $WLAN0_STATE"

    # Show MAC address
    WLAN0_MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null)
    echo "  MAC address: $WLAN0_MAC"
else
    log_error "wlan0 NOT FOUND"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "The wlan0 interface does not exist"
    echo ""
    echo "Available interfaces:"
    ip link show | grep -E "^[0-9]+:"
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Verify onboard WiFi is enabled"
    echo "2. Check: ls /sys/class/net/"
    echo "3. Check dmesg for WiFi driver errors: dmesg | grep -i wifi"
    echo ""
    exit 1
fi

# Make sure wlan0 is down before reconfiguring
echo "Bringing down wlan0..."
sudo ip link set wlan0 down 2>/dev/null || true
sleep 1

################################################################################
# Step 4: Load BATMAN-adv Module
################################################################################

log_step "Step 4: Loading BATMAN-adv kernel module"

sudo modprobe batman-adv 2>&1 | tee -a "$LOG_FILE"

if lsmod | grep -q batman; then
    log_success "batman-adv module loaded"

    # Show loaded modules
    echo "BATMAN modules:"
    lsmod | grep -E "batman|bridge"
else
    log_error "FAILED TO LOAD batman-adv MODULE"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    dmesg | tail -20 | grep -i batman
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Check if package installed: dpkg -l | grep batctl"
    echo "2. Try manual load: sudo modprobe batman-adv"
    echo "3. Check kernel version: uname -r"
    echo "4. Re-run Phase 3 (Package Installation)"
    echo ""
    exit 1
fi

################################################################################
# Step 5: Configure wlan0 for IBSS (Ad-hoc) Mode
################################################################################

log_step "Step 5: Configuring wlan0 for IBSS (Ad-hoc) mode"

echo "Setting wlan0 to IBSS mode..."
sudo iw dev wlan0 set type ibss 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "wlan0 set to IBSS mode"
else
    log_error "FAILED TO SET IBSS MODE"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "Command failed: iw dev wlan0 set type ibss"
    echo ""
    echo "Current wlan0 info:"
    iw dev wlan0 info 2>&1 || echo "Cannot get wlan0 info"
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Check if wlan0 is down: ip link show wlan0"
    echo "2. Try: sudo ip link set wlan0 down"
    echo "3. Check dmesg: dmesg | tail -20"
    echo ""
    exit 1
fi

# Bring interface up
echo "Bringing up wlan0..."
sudo ip link set wlan0 up 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "wlan0 interface brought up"
else
    log_error "FAILED TO BRING UP wlan0"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "Command failed: ip link set wlan0 up"
    dmesg | tail -10
    echo ""
    exit 1
fi

sleep 2

# Verify interface is up
WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
echo "wlan0 state after bringing up: $WLAN0_STATE"

if [ "$WLAN0_STATE" != "UP" ] && [ "$WLAN0_STATE" != "UNKNOWN" ]; then
    log_warning "wlan0 not in UP state (state: $WLAN0_STATE)"
    echo "Continuing anyway..."
fi

################################################################################
# Step 6: Join IBSS Network
################################################################################

log_step "Step 6: Joining IBSS mesh network: $MESH_SSID"

echo "Command: iw dev wlan0 ibss join $MESH_SSID ${MESH_FREQ} fixed-freq $MESH_BSSID"
sudo iw dev wlan0 ibss join "$MESH_SSID" ${MESH_FREQ} fixed-freq "$MESH_BSSID" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "Joined IBSS network"
else
    log_error "FAILED TO JOIN IBSS NETWORK"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "SSID: $MESH_SSID"
    echo "Frequency: ${MESH_FREQ} MHz (Channel $MESH_CHANNEL)"
    echo "BSSID: $MESH_BSSID"
    echo ""
    echo "Current wlan0 status:"
    iw dev wlan0 info
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Verify Device0 mesh is active:"
    echo "   ssh pi@<device0-ip> 'sudo batctl n'"
    echo ""
    echo "2. Check Device0 mesh SSID matches:"
    echo "   ssh pi@<device0-ip> 'iw dev wlan0 info'"
    echo ""
    echo "3. Common issues:"
    echo "   - SSID mismatch (must be exact)"
    echo "   - Channel mismatch"
    echo "   - Device0 mesh not running"
    echo ""
    exit 1
fi

sleep 3

# Verify IBSS connection
echo "Verifying IBSS mode..."
iw dev wlan0 info | tee -a "$LOG_FILE"

if sudo iw dev wlan0 info | grep -q "type IBSS"; then
    log_success "wlan0 confirmed in IBSS mode"
else
    log_warning "wlan0 may not be in IBSS mode correctly"
    echo "Check output above"
fi

################################################################################
# Step 7: Add wlan0 to BATMAN-adv
################################################################################

log_step "Step 7: Adding wlan0 to BATMAN-adv"

sudo batctl if add wlan0 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "wlan0 added to batman-adv"
else
    log_error "FAILED TO ADD wlan0 TO BATMAN-ADV"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "Command failed: batctl if add wlan0"
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Check batman-adv module: lsmod | grep batman"
    echo "2. Check batctl version: batctl -v"
    echo "3. Try manual: sudo batctl if add wlan0"
    echo ""
    exit 1
fi

sleep 2

# Verify interface was added
echo "Verifying batman-adv interface..."
sudo batctl if 2>&1 | tee -a "$LOG_FILE"

################################################################################
# Step 8: Bring Up bat0 Interface
################################################################################

log_step "Step 8: Bringing up bat0 virtual interface"

sudo ip link set bat0 up 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "bat0 interface up"
else
    log_error "FAILED TO BRING UP bat0"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "Command failed: ip link set bat0 up"
    echo ""
    echo "Check if bat0 exists:"
    ip link show bat0 2>&1 || echo "bat0 does not exist"
    echo ""
    exit 1
fi

sleep 2

# Verify bat0 exists
if ip link show bat0 &>/dev/null; then
    log_success "bat0 interface verified"
    ip link show bat0 | grep -E "bat0|state"
else
    log_error "bat0 interface does not exist after creation attempt"
    exit 1
fi

################################################################################
# Step 9: Assign Static IP to bat0
################################################################################

log_step "Step 9: Assigning IP $DEVICE_IP to bat0"

sudo ip addr add ${DEVICE_IP}/24 dev bat0 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "IP assigned to bat0"
else
    # Check if IP is already assigned
    if ip addr show bat0 | grep -q "$DEVICE_IP"; then
        log_warning "IP already assigned (this is OK)"
    else
        log_error "FAILED TO ASSIGN IP"
        echo ""
        echo "═══ ERROR DETAILS ═══"
        echo "Command failed: ip addr add ${DEVICE_IP}/24 dev bat0"
        echo ""
        echo "Current bat0 status:"
        ip addr show bat0
        echo ""
        exit 1
    fi
fi

# Verify IP assignment
BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
if [ "$BAT0_IP" == "${DEVICE_IP}/24" ]; then
    log_success "Verified: bat0 has IP $BAT0_IP"
else
    log_error "IP VERIFICATION FAILED"
    echo "Expected: ${DEVICE_IP}/24"
    echo "Got: $BAT0_IP"
    echo ""
    echo "Current bat0 configuration:"
    ip addr show bat0
    echo ""
fi

################################################################################
# Step 10: Test Connection to Device0
################################################################################

log_step "Step 10: Testing connection to Device0 (192.168.99.100)"

echo "Waiting 5 seconds for mesh to establish..."
sleep 5

echo "Attempting ping to Device0..."
if ping -c 3 -W 5 192.168.99.100 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Can ping Device0!"
else
    log_warning "Cannot ping Device0 yet"
    echo ""
    echo "═══ DIAGNOSTIC INFO ═══"
    echo "This may be normal if Device0 mesh is not active yet"
    echo ""
    echo "Routing table:"
    ip route show
    echo ""
    echo "ARP table:"
    ip neigh show
    echo ""
    echo "═══ NEXT STEPS ═══"
    echo "1. Verify Device0 mesh is running:"
    echo "   ssh pi@<device0-ip> 'sudo systemctl status batman-mesh'"
    echo ""
    echo "2. Check Device0 mesh neighbors:"
    echo "   ssh pi@<device0-ip> 'sudo batctl n'"
    echo ""
    echo "3. After Phase 5, try again:"
    echo "   ping 192.168.99.100"
    echo ""
fi

################################################################################
# Step 11: Check Mesh Neighbors
################################################################################

log_step "Step 11: Checking mesh neighbors"

echo "Batman-adv neighbor list:"
sudo batctl n 2>&1 | tee -a "$LOG_FILE"

NEIGHBORS=$(sudo batctl n 2>/dev/null)

if echo "$NEIGHBORS" | grep -q "192.168.99.100"; then
    log_success "Device0 visible in mesh neighbors"
elif echo "$NEIGHBORS" | grep -q "No batman"; then
    log_warning "No mesh neighbors detected yet"
    echo "This may take a few minutes to populate"
else
    log_info "Neighbors detected (may not include Device0 yet)"
fi

################################################################################
# Step 12: Create Systemd Service for Mesh Startup
################################################################################

log_step "Step 12: Creating systemd service for mesh network"

sudo tee /etc/systemd/system/batman-mesh-client.service > /dev/null << EOF
[Unit]
Description=BATMAN-adv Mesh Network (Client Device${DEVICE_NUM})
After=network.target network-online.target
Wants=network-online.target
Before=field-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log_success "Systemd service created"

################################################################################
# Step 13: Create Mesh Startup Script
################################################################################

log_step "Step 13: Creating mesh startup script"

sudo tee /usr/local/bin/start-batman-mesh-client.sh > /dev/null << EOF
#!/bin/bash

# Field Trainer - Client Mesh Startup Script
# Device${DEVICE_NUM} - IP: ${DEVICE_IP}

MESH_IFACE="wlan0"
MESH_SSID="${MESH_SSID}"
MESH_FREQ="${MESH_FREQ}"
MESH_BSSID="${MESH_BSSID}"
DEVICE_IP="${DEVICE_IP}"

# Load batman-adv module
modprobe batman-adv

# Bring down interface
ip link set \${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev \${MESH_IFACE} set type ibss

# Bring interface up
ip link set \${MESH_IFACE} up

# Join IBSS network
iw dev \${MESH_IFACE} ibss join \${MESH_SSID} \${MESH_FREQ} fixed-freq \${MESH_BSSID}

# Add interface to batman-adv
batctl if add \${MESH_IFACE}

# Bring up bat0 interface
ip link set bat0 up

# Assign IP to bat0
ip addr add \${DEVICE_IP}/24 dev bat0

echo "BATMAN mesh started on \${MESH_IFACE}"
echo "Device IP: \${DEVICE_IP}"
EOF

sudo chmod +x /usr/local/bin/start-batman-mesh-client.sh
log_success "Startup script created: /usr/local/bin/start-batman-mesh-client.sh"

################################################################################
# Step 14: Create Mesh Shutdown Script
################################################################################

log_step "Step 14: Creating mesh shutdown script"

sudo tee /usr/local/bin/stop-batman-mesh-client.sh > /dev/null << EOF
#!/bin/bash

# Field Trainer - Client Mesh Shutdown Script

# Remove IP from bat0
ip addr flush dev bat0

# Bring down bat0
ip link set bat0 down

# Remove wlan0 from batman-adv
batctl if del wlan0

# Leave IBSS network
iw dev wlan0 ibss leave

# Bring down wlan0
ip link set wlan0 down

echo "BATMAN mesh stopped"
EOF

sudo chmod +x /usr/local/bin/stop-batman-mesh-client.sh
log_success "Shutdown script created"

################################################################################
# Step 15: Enable Mesh Service
################################################################################

log_step "Step 15: Enabling mesh service"

sudo systemctl daemon-reload
sudo systemctl enable batman-mesh-client.service 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "Mesh service enabled (will start on boot)"
else
    log_error "Failed to enable mesh service"
    echo "Check systemd logs: journalctl -xe"
    exit 1
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mesh Network Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Device: Device${DEVICE_NUM}"
echo "  IP Address: $DEVICE_IP"
echo "  Mesh SSID: $MESH_SSID"
echo "  Mesh Channel: $MESH_CHANNEL"
echo ""
echo "  Status:"
echo "    ✓ wlan0 in IBSS mode"
echo "    ✓ BATMAN-adv active"
echo "    ✓ bat0 interface up"
echo "    ✓ Static IP assigned"
echo "    ✓ Systemd service enabled"
echo ""
echo "  Test Commands:"
echo "    ping 192.168.99.100          # Ping Device0"
echo "    sudo batctl n                # View mesh neighbors"
echo "    iw dev wlan0 info            # Check wlan0 status"
echo "    ip addr show bat0            # Check bat0 IP"
echo ""
echo "  Log file saved to: $LOG_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Phase 4 complete!"

echo ""
echo "Ready for Phase 5: Client Application Deployment"
echo ""

# Copy log to USB for review
if [ -d "/mnt/usb/ft_usb_build" ]; then
    cp "$LOG_FILE" "/mnt/usb/ft_usb_build/phase4_mesh_Device${DEVICE_NUM}_$(date +%Y%m%d_%H%M%S).log"
    echo "Log copied to USB drive for review"
fi

exit 0

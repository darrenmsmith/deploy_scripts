#!/bin/bash

################################################################################
# Field Trainer - Client Phase 4: Mesh Network Join
# Join BATMAN-adv mesh network and connect to Device0
# Enhanced with detailed error logging and diagnostics
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 4: Mesh Network Join"

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
# Step 2: Mesh Network Configuration - Auto-Detect from Device0
################################################################################

log_step "Step 2: Auto-detecting mesh network configuration"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mesh Network Auto-Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Default values
DEFAULT_MESH_SSID="ft_mesh2"
DEFAULT_MESH_CHANNEL=1
DEFAULT_MESH_BSSID="00:11:22:33:44:55"

MESH_SSID=""
MESH_CHANNEL=""
MESH_BSSID=""

# Try to detect mesh configuration from Device0
echo "Attempting to detect mesh configuration from Device0 (192.168.99.100)..."
echo ""

# Check if we can reach Device0
if ping -c 2 -W 2 192.168.99.100 >/dev/null 2>&1; then
    log_success "Device0 is reachable - attempting to get mesh config"

    # Try to get mesh config via SSH (assuming same credentials)
    # This will only work if SSH is set up with keys or known password
    DEVICE0_WLAN0_INFO=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no pi@192.168.99.100 "iw dev wlan0 info" 2>/dev/null || echo "")

    if [ -n "$DEVICE0_WLAN0_INFO" ]; then
        # Extract SSID
        DETECTED_SSID=$(echo "$DEVICE0_WLAN0_INFO" | grep "ssid" | awk '{print $2}')

        # Extract channel
        DETECTED_CHANNEL=$(echo "$DEVICE0_WLAN0_INFO" | grep "channel" | awk '{print $2}')

        if [ -n "$DETECTED_SSID" ]; then
            MESH_SSID="$DETECTED_SSID"
            log_success "Detected mesh SSID from Device0: $MESH_SSID"
        fi

        if [ -n "$DETECTED_CHANNEL" ]; then
            MESH_CHANNEL="$DETECTED_CHANNEL"
            log_success "Detected mesh channel from Device0: $MESH_CHANNEL"
        fi
    else
        log_info "Could not SSH to Device0 (expected on fresh deployment)"
    fi
else
    log_info "Device0 not reachable yet (normal for fresh deployment)"
fi

echo ""

# If we couldn't detect, check if mesh is already configured on this device
if [ -z "$MESH_SSID" ]; then
    if ip link show wlan0 >/dev/null 2>&1; then
        CURRENT_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')
        if [ -n "$CURRENT_SSID" ] && [ "$CURRENT_SSID" != "off/any" ]; then
            MESH_SSID="$CURRENT_SSID"
            log_success "Using existing wlan0 SSID: $MESH_SSID"
        fi
    fi
fi

# If still no SSID, use defaults and prompt
if [ -z "$MESH_SSID" ]; then
    echo "Could not auto-detect mesh configuration."
    echo "Using defaults (you can change if needed):"
    echo ""

    read -p "Enter mesh SSID (default: $DEFAULT_MESH_SSID): " USER_MESH_SSID
    MESH_SSID=${USER_MESH_SSID:-$DEFAULT_MESH_SSID}

    read -p "Enter mesh channel (default: $DEFAULT_MESH_CHANNEL): " USER_MESH_CHANNEL
    MESH_CHANNEL=${USER_MESH_CHANNEL:-$DEFAULT_MESH_CHANNEL}
else
    # Auto-detected - ask if user wants to change
    echo "Auto-detected configuration:"
    echo "  SSID: $MESH_SSID"
    echo "  Channel: ${MESH_CHANNEL:-$DEFAULT_MESH_CHANNEL}"
    echo ""

    read -p "Use this configuration? (Y/n): " USE_DETECTED
    if [[ "$USE_DETECTED" =~ ^[Nn]$ ]]; then
        read -p "Enter mesh SSID (default: $MESH_SSID): " USER_MESH_SSID
        MESH_SSID=${USER_MESH_SSID:-$MESH_SSID}

        read -p "Enter mesh channel (default: ${MESH_CHANNEL:-$DEFAULT_MESH_CHANNEL}): " USER_MESH_CHANNEL
        MESH_CHANNEL=${USER_MESH_CHANNEL:-${MESH_CHANNEL:-$DEFAULT_MESH_CHANNEL}}
    fi
fi

# Set defaults if still empty
MESH_SSID=${MESH_SSID:-$DEFAULT_MESH_SSID}
MESH_CHANNEL=${MESH_CHANNEL:-$DEFAULT_MESH_CHANNEL}
MESH_BSSID=$DEFAULT_MESH_BSSID

echo ""
log_success "Mesh configuration:"
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
# Step 4: Configure NetworkManager to Ignore wlan0
################################################################################

log_step "Step 4: Configuring NetworkManager to ignore wlan0"

echo ""
echo "NetworkManager interferes with mesh networking by trying to manage wlan0."
echo "We will mark wlan0 as 'unmanaged' so NetworkManager ignores it."
echo "This allows wlan1 (if present) to remain available for other uses."
echo ""

# Check if NetworkManager is installed
if command -v nmcli &>/dev/null; then
    log_info "NetworkManager detected - configuring to ignore wlan0"

    # Create unmanaged config to mark wlan0 and bat0 as unmanaged
    # This allows wlan1 to remain available for NetworkManager if needed
    echo "Creating NetworkManager unmanaged config..."
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/99-unmanage-wlan0.conf > /dev/null << 'NMCONF'
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:bat0

[device]
wifi.scan-rand-mac-address=no
NMCONF

    log_success "NetworkManager config created"

    # Restart NetworkManager to apply config
    echo "Restarting NetworkManager to apply configuration..."
    sudo systemctl restart NetworkManager.service 2>/dev/null || true
    sleep 3

    # Show device status
    echo ""
    echo "NetworkManager device status:"
    nmcli device status 2>&1 | tee -a "$LOG_FILE"
    echo ""

    # Verify wlan0 is now unmanaged
    WLAN0_NM_STATE=$(nmcli device status 2>/dev/null | grep "^wlan0" | awk '{print $3}')
    echo "wlan0 NetworkManager state: $WLAN0_NM_STATE"

    if [ "$WLAN0_NM_STATE" == "unmanaged" ]; then
        log_success "wlan0 is now unmanaged by NetworkManager"
    else
        log_warning "wlan0 state is '$WLAN0_NM_STATE' (expected 'unmanaged')"
        echo "The mesh may still work, but NetworkManager might interfere"
    fi

    # Check if wlan1 exists and show its status
    if ip link show wlan1 &>/dev/null; then
        WLAN1_NM_STATE=$(nmcli device status 2>/dev/null | grep "^wlan1" | awk '{print $3}')
        log_info "wlan1 detected - NetworkManager state: $WLAN1_NM_STATE"
        echo "  wlan1 is available for NetworkManager (internet connectivity, etc.)"
    else
        log_info "wlan1 not detected (only onboard wlan0 present)"
    fi

    log_success "NetworkManager configured - wlan0 unmanaged, wlan1 available"
else
    log_info "NetworkManager not installed (no interference possible)"
fi

echo ""

################################################################################
# Step 5: Load BATMAN-adv Module
################################################################################

log_step "Step 5: Loading BATMAN-adv kernel module"

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
# Step 6: Unblock RF-kill (Critical for WiFi)
################################################################################

log_step "Step 6: Unblocking RF-kill for WiFi"

echo ""
echo "RF-kill can block WiFi hardware. We need to unblock it before using wlan0."
echo ""

# Show current RF-kill status
echo "Current RF-kill status:"
sudo rfkill list 2>&1 | tee -a "$LOG_FILE"
echo ""

# Unblock all WiFi devices
echo "Unblocking WiFi devices..."
sudo rfkill unblock all 2>&1 | tee -a "$LOG_FILE"
sleep 2

# Verify unblocked
echo ""
echo "RF-kill status after unblock:"
sudo rfkill list 2>&1 | tee -a "$LOG_FILE"
echo ""

# Check if phy0 is still blocked
if sudo rfkill list | grep -A 1 "phy0" | grep -q "Soft blocked: yes"; then
    log_error "RF-kill still blocking phy0 after unblock attempt"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    sudo rfkill list
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Check for hardware RF-kill switch on device"
    echo "2. Try: sudo rfkill unblock 0"
    echo "3. Try: sudo rfkill unblock wifi"
    echo "4. Reboot and try again"
    echo ""
    echo "Attempting to continue anyway..."
elif sudo rfkill list | grep -A 1 "phy0" | grep -q "Hard blocked: yes"; then
    log_error "RF-kill HARDWARE block detected"
    echo ""
    echo "═══ ERROR DETAILS ═══"
    echo "The WiFi hardware has a physical hardware block (hard block)."
    echo "This usually means there's a physical switch or BIOS setting."
    echo ""
    sudo rfkill list
    echo ""
    echo "═══ TROUBLESHOOTING ═══"
    echo "1. Check for physical WiFi switch on device"
    echo "2. Check BIOS/firmware settings"
    echo "3. Some hardware doesn't support WiFi - verify your hardware"
    echo ""
    exit 1
else
    log_success "RF-kill unblocked - WiFi hardware ready"
fi

echo ""

################################################################################
# Step 7: Configure wlan0 for IBSS (Ad-hoc) Mode
################################################################################

log_step "Step 7: Configuring wlan0 for IBSS (Ad-hoc) mode"

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
# Step 8: Join IBSS Network
################################################################################

log_step "Step 8: Joining IBSS mesh network: $MESH_SSID"

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
# Step 9: Add wlan0 to BATMAN-adv
################################################################################

log_step "Step 9: Adding wlan0 to BATMAN-adv"

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
# Step 10: Bring Up bat0 Interface
################################################################################

log_step "Step 10: Bringing up bat0 virtual interface"

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
# Step 11: Assign Static IP to bat0
################################################################################

log_step "Step 11: Assigning IP $DEVICE_IP to bat0"

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
# Step 12: Test Connection to Device0
################################################################################

log_step "Step 12: Testing connection to Device0 (192.168.99.100)"

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
# Step 13: Check Mesh Neighbors
################################################################################

log_step "Step 13: Checking mesh neighbors"

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
# Step 14: Configure wlan1 for WiFi/Internet (Optional)
################################################################################

log_step "Step 14: Configuring wlan1 for WiFi/Internet (Optional)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "wlan1 Configuration (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If you have an external USB WiFi adapter (wlan1), you can configure it"
echo "to connect to your development WiFi network for:"
echo "  • Direct SSH access from your laptop"
echo "  • Internet connectivity for updates"
echo "  • File transfers and debugging"
echo ""
echo "Note: wlan0 will continue to handle the mesh network to Device0"
echo ""

# Check if wlan1 exists
if ip link show wlan1 &>/dev/null; then
    log_success "wlan1 interface detected"

    # Show wlan1 hardware info
    WLAN1_MAC=$(cat /sys/class/net/wlan1/address 2>/dev/null)
    echo "  wlan1 MAC address: $WLAN1_MAC"

    # Check if wlan1 is already connected
    WLAN1_STATUS=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep "^wlan1:" | cut -d':' -f2)
    WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    WLAN1_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi list ifname wlan1 2>/dev/null | grep "^yes" | cut -d':' -f2)

    echo ""

    if [ "$WLAN1_STATUS" == "connected" ] && [ -n "$WLAN1_IP" ]; then
        log_success "wlan1 is already connected to WiFi"
        echo "  Current connection:"
        echo "    SSID: ${WLAN1_SSID:-Unknown}"
        echo "    IP: $WLAN1_IP"
        echo "    Status: Connected"
        echo ""
        echo "  You can SSH to this device at: ssh pi@$WLAN1_IP"
        echo ""

        read -p "Reconfigure wlan1? (y/N): " RECONFIGURE_WLAN1
        if [[ ! "$RECONFIGURE_WLAN1" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing wlan1 configuration"
        else
            CONFIGURE_WLAN1="y"
        fi
    else
        # Not connected - ask if user wants to configure
        echo "  wlan1 is not connected to WiFi"
        echo ""
        read -p "Do you want to configure wlan1 for WiFi connectivity? (y/n): " CONFIGURE_WLAN1
    fi

    if [[ "$CONFIGURE_WLAN1" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Scanning for available WiFi networks on wlan1..."
        echo ""

        # Scan for networks
        sudo nmcli device wifi list ifname wlan1 2>&1 | head -20 || {
            log_warning "Could not scan WiFi networks"
            echo "You can configure wlan1 manually later using:"
            echo "  nmcli device wifi connect 'SSID' password 'PASSWORD'"
        }

        echo ""
        read -p "Enter WiFi SSID to connect to: " WIFI_SSID

        if [ -n "$WIFI_SSID" ]; then
            read -sp "Enter WiFi password: " WIFI_PASSWORD
            echo ""
            echo ""

            echo "Connecting wlan1 to '$WIFI_SSID'..."
            if sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" ifname wlan1 2>&1 | tee -a "$LOG_FILE"; then
                log_success "wlan1 connected to WiFi"

                # Wait for IP assignment
                sleep 3

                # Get IP address
                WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

                if [ -n "$WLAN1_IP" ]; then
                    log_success "wlan1 IP address: $WLAN1_IP"
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "  SSH Access Information"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo ""
                    echo "  You can now SSH to this device from your laptop:"
                    echo ""
                    echo "    ssh pi@$WLAN1_IP"
                    echo ""
                    echo "  Network Configuration:"
                    echo "    wlan0 (mesh): 192.168.99.10${DEVICE_NUM} → Device0 mesh network"
                    echo "    wlan1 (WiFi): $WLAN1_IP → Your WiFi network"
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo ""
                else
                    log_warning "Connected but no IP address assigned yet"
                    echo "Check connection: nmcli device status"
                fi

                # Make connection auto-connect on boot
                CONNECTION_NAME=$(nmcli -t -f NAME,DEVICE connection show | grep "wlan1" | cut -d':' -f1 | head -1)
                if [ -n "$CONNECTION_NAME" ]; then
                    sudo nmcli connection modify "$CONNECTION_NAME" connection.autoconnect yes 2>/dev/null
                    log_success "WiFi connection will auto-connect on boot"
                fi

            else
                log_error "Failed to connect to WiFi"
                echo ""
                echo "═══ TROUBLESHOOTING ═══"
                echo "1. Verify SSID is correct"
                echo "2. Verify password is correct"
                echo "3. Try manual connection:"
                echo "   nmcli device wifi connect '$WIFI_SSID' password 'PASSWORD' ifname wlan1"
                echo ""
                echo "Continuing with mesh setup..."
            fi
        else
            log_info "No SSID entered - skipping wlan1 configuration"
        fi
    else
        log_info "Skipping wlan1 WiFi configuration"
        echo ""
        echo "You can configure wlan1 later using:"
        echo "  nmcli device wifi list ifname wlan1"
        echo "  nmcli device wifi connect 'SSID' password 'PASSWORD' ifname wlan1"
        echo ""
    fi
else
    log_info "wlan1 not detected - only using wlan0 for mesh network"
    echo ""
    echo "If you add an external USB WiFi adapter later, you can configure it with:"
    echo "  nmcli device wifi list ifname wlan1"
    echo "  nmcli device wifi connect 'SSID' password 'PASSWORD' ifname wlan1"
    echo ""
fi

echo ""

################################################################################
# Step 15: Create Systemd Service for Mesh Startup
################################################################################

log_step "Step 15: Creating systemd service for mesh network"

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
# Step 16: Create Mesh Startup Script
################################################################################

log_step "Step 16: Creating mesh startup script"

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

# Unblock WiFi (RF-kill fix) - must be AFTER modprobe
# Only unblock wlan0 specifically if possible, otherwise unblock all WiFi
rfkill unblock all 2>/dev/null || true
sleep 1

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

# Add default gateway route through Device0 (gateway)
ip route add default via 192.168.99.100 2>/dev/null || true

echo "BATMAN mesh started on \${MESH_IFACE}"
echo "Device IP: \${DEVICE_IP}"
echo "Note: wlan0 is used for mesh, wlan1 (if present) remains available"
EOF

sudo chmod +x /usr/local/bin/start-batman-mesh-client.sh
log_success "Startup script created: /usr/local/bin/start-batman-mesh-client.sh"

################################################################################
# Step 17: Create Mesh Shutdown Script
################################################################################

log_step "Step 17: Creating mesh shutdown script"

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
# Step 18: Enable Mesh Service
################################################################################

log_step "Step 18: Enabling mesh service"

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
# Step 19: Configure DNS Nameservers
################################################################################

log_step "Step 19: Configuring DNS nameservers"

# Write to resolv.conf.tail so it persists across dhcpcd regeneration
sudo tee /etc/resolv.conf.tail > /dev/null << 'DNSEOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
DNSEOF

# Also append directly to resolv.conf for immediate effect
grep -q "nameserver 8.8.8.8" /etc/resolv.conf 2>/dev/null || \
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null

log_success "DNS nameservers configured (8.8.8.8, 8.8.4.4)"

# Verify DNS resolution
echo -n "  Testing DNS resolution... "
if ping -c 1 -W 5 raspbian.raspberrypi.com &>/dev/null; then
    log_success "DNS working"
else
    log_warning "DNS test failed - internet may not be routed yet (normal if Device0 not running)"
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 4 Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Device: Device${DEVICE_NUM}"
echo ""
echo "  Mesh Network (wlan0):"
echo "    • IP Address: $DEVICE_IP"
echo "    • Mesh SSID: $MESH_SSID"
echo "    • Channel: $MESH_CHANNEL"
echo "    • Mode: IBSS (Ad-hoc)"
echo "    • Purpose: BATMAN-adv mesh to Device0"
echo ""

# Show wlan1 info if it was configured
if ip link show wlan1 &>/dev/null; then
    WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    WLAN1_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi list ifname wlan1 2>/dev/null | grep "^yes" | cut -d':' -f2)

    if [ -n "$WLAN1_IP" ]; then
        echo "  WiFi Network (wlan1):"
        echo "    • IP Address: $WLAN1_IP"
        if [ -n "$WLAN1_SSID" ]; then
            echo "    • WiFi SSID: $WLAN1_SSID"
        fi
        echo "    • Purpose: SSH access, internet, development"
        echo "    • Auto-connect: Enabled"
        echo ""
        echo "  SSH Access:"
        echo "    ssh pi@$WLAN1_IP"
        echo ""
    else
        echo "  WiFi Network (wlan1):"
        echo "    • Status: Detected but not configured"
        echo "    • Configure with: nmcli device wifi connect 'SSID' password 'PASSWORD' ifname wlan1"
        echo ""
    fi
fi

echo "  Status:"
echo "    ✓ NetworkManager: wlan0 unmanaged, wlan1 available"
echo "    ✓ wlan0 in IBSS mode"
echo "    ✓ BATMAN-adv active"
echo "    ✓ bat0 interface up"
echo "    ✓ Static IP assigned: $DEVICE_IP"
echo "    ✓ Default gateway: 192.168.99.100 (Device0)"
echo "    ✓ DNS nameservers: 8.8.8.8, 8.8.4.4"
echo "    ✓ Systemd service enabled"
echo ""
echo "  Test Commands:"
echo "    ping 192.168.99.100          # Ping Device0 via mesh"
echo "    sudo batctl n                # View mesh neighbors"
echo "    iw dev wlan0 info            # Check wlan0 mesh status"
echo "    ip addr show bat0            # Check bat0 IP"

if ip link show wlan1 &>/dev/null; then
    echo "    ip addr show wlan1           # Check wlan1 WiFi status"
    echo "    nmcli device status          # Show all network devices"
fi

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

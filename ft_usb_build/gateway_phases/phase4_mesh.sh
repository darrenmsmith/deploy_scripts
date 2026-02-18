#!/bin/bash

################################################################################
# Phase 3: BATMAN Mesh Network (wlan0)
# Configures wlan0 for BATMAN-adv mesh networking
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

ERRORS=0

# USB logging - capture all output to log file
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase4_mesh_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase4_mesh_latest.log"
echo "========================================" && echo "Field Trainer Installation - Phase 4: Mesh" && echo "Date: $(date)" && echo "Hostname: $(hostname)" && echo "Log: $LOG_FILE" && echo "========================================"
echo ""

# Default mesh configuration
MESH_IFACE="wlan0"
DEFAULT_MESH_IP="192.168.99.100/24"
DEFAULT_MESH_SSID="ft_mesh"
MESH_BSSID="00:11:22:33:44:55"

echo "Phase 3: BATMAN Mesh Network (wlan0)"
echo "====================================="
echo ""
echo "This phase configures wlan0 (onboard WiFi) for BATMAN-adv mesh."
echo ""
echo "Configuration will create:"
echo "  • /usr/local/bin/start-batman-mesh.sh (mesh startup script)"
echo "  • /etc/systemd/system/batman-mesh.service (auto-start service)"
echo ""
echo "Default mesh configuration:"
echo "  • Interface: $MESH_IFACE (onboard WiFi)"
echo "  • IP Address: $DEFAULT_MESH_IP"
echo "  • SSID: $DEFAULT_MESH_SSID"
echo "  • Mode: IBSS (Ad-hoc)"
echo ""
read -p "Press Enter to begin configuration..."
echo ""

################################################################################
# Step 1: Verify Prerequisites
################################################################################

echo "Step 1: Verifying Prerequisites..."
echo "-----------------------------------"

# Check batman-adv module
echo -n "  batman-adv module... "
if modinfo batman_adv &>/dev/null; then
    print_success "available"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# Check batctl
echo -n "  batctl command... "
if command -v batctl &>/dev/null; then
    print_success "available"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

# Check wlan0 exists
echo -n "  wlan0 interface... "
if ip link show wlan0 &>/dev/null; then
    print_success "found"
else
    print_error "not found"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Prerequisites not met. Please complete Phase 1 first."
    exit 1
fi

################################################################################
# Step 2: Test IBSS Support on wlan0
################################################################################

echo "Step 2: Testing IBSS Support..."
echo "--------------------------------"

print_info "Testing IBSS (Ad-hoc) mode on wlan0..."

# Bring interface down first
sudo ip link set wlan0 down 2>/dev/null
sleep 1

# Test IBSS mode
if sudo iw dev wlan0 set type ibss 2>/dev/null; then
    print_success "wlan0 supports IBSS mode"
    sudo iw dev wlan0 set type managed 2>/dev/null
else
    print_error "wlan0 does NOT support IBSS mode"
    print_warning "IBSS support is REQUIRED for BATMAN mesh"
    echo ""
    echo "  Troubleshooting steps:"
    echo "    1. Check RF-kill status: rfkill list"
    echo "    2. Unblock if needed: sudo rfkill unblock wifi"
    echo "    3. Ensure no other services are using wlan0"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    exit 1
fi

################################################################################
# Step 3: Configure Mesh IP Address
################################################################################

echo "Step 3: Mesh IP Configuration..."
echo "--------------------------------"
echo ""
echo "Device 0 is the gateway and should use: $DEFAULT_MESH_IP"
echo ""

# Auto-use default IP if running non-interactively (via menu system)
if [ -t 0 ]; then
    # Interactive - ask user
    read -p "Use default IP address $DEFAULT_MESH_IP? (y/n): " use_default_ip

    if [[ $use_default_ip =~ ^[Yy]$ ]]; then
        MESH_IP="$DEFAULT_MESH_IP"
    else
        while true; do
            read -p "Enter mesh IP address (format: 192.168.99.100/24): " MESH_IP
            if [[ $MESH_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                break
            else
                print_error "Invalid IP format. Use: IP/CIDR (e.g., 192.168.99.100/24)"
            fi
        done
    fi
else
    # Non-interactive - use defaults
    print_info "Auto-using default IP (non-interactive mode): $DEFAULT_MESH_IP"
    MESH_IP="$DEFAULT_MESH_IP"
fi

print_info "Using mesh IP: $MESH_IP"
echo ""

################################################################################
# Step 3b: Configure Mesh SSID
################################################################################

echo "Step 3b: Mesh Network Name (SSID)..."
echo "-------------------------------------"
echo ""
echo "The mesh SSID must be the SAME on all devices (0-5) to form a network."
echo "Default SSID: $DEFAULT_MESH_SSID"
echo ""

# Always ask for mesh SSID confirmation (important for multi-device setup)
read -p "Use default mesh SSID '$DEFAULT_MESH_SSID'? (y/n): " use_default_ssid < /dev/tty

if [[ $use_default_ssid =~ ^[Yy]$ ]]; then
    MESH_SSID="$DEFAULT_MESH_SSID"
else
    while true; do
        read -p "Enter mesh network SSID (e.g., ft_mesh, fieldtrainer, myteam): " MESH_SSID < /dev/tty
        if [ -n "$MESH_SSID" ] && [[ "$MESH_SSID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            print_error "Invalid SSID. Use only letters, numbers, underscore, or dash"
        fi
    done
fi

print_info "Using mesh SSID: $MESH_SSID"
echo ""
print_warning "IMPORTANT: All devices (1-5) must use the SAME mesh SSID: $MESH_SSID"
echo ""

################################################################################
# Step 4: Prevent Network Manager Interference
################################################################################

echo "Step 4: Preventing Network Manager Interference..."
echo "---------------------------------------------------"

print_info "Disabling NetworkManager and wpa_supplicant for wlan0..."

# Stop and disable NetworkManager if running
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    print_info "Stopping NetworkManager..."
    sudo systemctl stop NetworkManager 2>/dev/null
    sudo systemctl disable NetworkManager 2>/dev/null
    print_success "NetworkManager disabled"
else
    print_info "NetworkManager not active (ok)"
fi

# Prevent wpa_supplicant from managing wlan0
print_info "Masking wpa_supplicant for wlan0..."
sudo systemctl mask wpa_supplicant@wlan0 2>/dev/null
sudo systemctl stop wpa_supplicant@wlan0 2>/dev/null
sudo pkill -f "wpa_supplicant.*wlan0" 2>/dev/null
print_success "wpa_supplicant masked for wlan0"

echo ""
print_warning "wlan0 is now reserved exclusively for BATMAN mesh networking"
print_info "wlan1 will remain available for internet/SSH access"
echo ""

################################################################################
# Step 5: Create Mesh Startup Script
################################################################################

echo "Step 5: Creating Mesh Startup Script..."
echo "----------------------------------------"

MESH_SCRIPT="/usr/local/bin/start-batman-mesh.sh"

print_info "Creating $MESH_SCRIPT"

sudo tee "$MESH_SCRIPT" > /dev/null << EOF
#!/bin/bash

################################################################################
# Field Trainer - BATMAN-adv Mesh Network Startup
# Device 0 - Gateway Configuration
# IP: $MESH_IP
################################################################################

MESH_IFACE="$MESH_IFACE"
MESH_IP="$MESH_IP"
MESH_SSID="$MESH_SSID"
MESH_CHANNEL="1"

echo "Starting BATMAN-adv mesh network..."

# Load batman-adv module
modprobe batman-adv
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to load batman-adv module"
    exit 1
fi

# Unblock WiFi (RF-kill fix)
rfkill unblock wifi

# Bring down interface
ip link set \${MESH_IFACE} down

# Set interface to IBSS (Ad-hoc) mode
iw dev \${MESH_IFACE} set type ibss
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to set IBSS mode on \${MESH_IFACE}"
    exit 1
fi

# Bring interface up
ip link set \${MESH_IFACE} up
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to bring up \${MESH_IFACE}"
    exit 1
fi

# Join IBSS network (2412 = Channel 1)
# First leave if already joined (idempotent)
iw dev \${MESH_IFACE} ibss leave 2>/dev/null
iw dev \${MESH_IFACE} ibss join \${MESH_SSID} 2412 fixed-freq $MESH_BSSID
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to join IBSS network"
    exit 1
fi

# Small delay for interface to stabilize
sleep 2

# Add interface to batman-adv (idempotent - batctl handles this)
batctl if add \${MESH_IFACE}
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to add \${MESH_IFACE} to batman-adv"
    exit 1
fi

# Bring up bat0 interface
ip link set bat0 up
if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to bring up bat0"
    exit 1
fi

# Assign IP to bat0 (idempotent - only add if not already assigned)
if ! ip addr show bat0 | grep -q "\${MESH_IP}"; then
    ip addr add \${MESH_IP} dev bat0
    if [ \$? -ne 0 ]; then
        echo "ERROR: Failed to assign IP to bat0"
        exit 1
    fi
    echo "IP \${MESH_IP} assigned to bat0"
else
    echo "IP \${MESH_IP} already assigned to bat0 (ok)"
fi

echo "SUCCESS: BATMAN mesh started on \${MESH_IFACE}"
echo "  bat0 configured with IP \${MESH_IP}"
echo "  SSID: \${MESH_SSID}"

# Show mesh status
echo ""
echo "Mesh interface status:"
iw dev \${MESH_IFACE} info
echo ""
echo "bat0 status:"
ip addr show bat0

exit 0
EOF

if [ $? -eq 0 ]; then
    sudo chmod +x "$MESH_SCRIPT"
    print_success "Mesh startup script created and made executable"
else
    print_error "Failed to create mesh startup script"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 6: Test Mesh Script
################################################################################

echo "Step 6: Testing Mesh Startup..."
echo "--------------------------------"

print_info "Running mesh startup script..."
echo ""

if sudo "$MESH_SCRIPT"; then
    print_success "Mesh startup script executed successfully!"
    echo ""
    
    # Verify bat0 interface
    print_info "Verifying bat0 interface..."
    if ip addr show bat0 &>/dev/null; then
        IP_INFO=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
        print_success "bat0 is up with IP: $IP_INFO"
    else
        print_error "bat0 interface not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Show mesh info
    echo ""
    print_info "Mesh interface info:"
    iw dev wlan0 info | head -n 10
    
else
    print_error "Mesh startup script failed"
    ERRORS=$((ERRORS + 1))

    echo ""
    print_warning "Capturing diagnostic information..."
    echo ""

    # Create diagnostic log
    DIAG_LOG="/tmp/phase4_mesh_failure_$(date +%Y%m%d_%H%M%S).log"

    {
        echo "════════════════════════════════════════════════════════════"
        echo "Phase 4 Mesh Network Failure Diagnostics"
        echo "Timestamp: $(date)"
        echo "════════════════════════════════════════════════════════════"
        echo ""

        echo "[1] RF-kill status:"
        echo "──────────────────────────────────────"
        rfkill list
        echo ""

        echo "[2] wlan0 interface status:"
        echo "──────────────────────────────────────"
        ip addr show wlan0 2>/dev/null || echo "wlan0 not found"
        echo ""
        iw dev wlan0 info 2>/dev/null || echo "wlan0 wireless info unavailable"
        echo ""

        echo "[3] bat0 interface status:"
        echo "──────────────────────────────────────"
        ip addr show bat0 2>/dev/null || echo "bat0 not found"
        echo ""

        echo "[4] batman-adv status:"
        echo "──────────────────────────────────────"
        lsmod | grep batman || echo "batman-adv module not loaded"
        echo ""
        sudo batctl if 2>/dev/null || echo "batctl not available or no interfaces"
        echo ""

        echo "[5] Recent startup script output:"
        echo "──────────────────────────────────────"
        sudo journalctl -n 50 --no-pager 2>/dev/null | grep -i "batman\|mesh\|wlan0" || echo "No recent logs"
        echo ""

        echo "[6] Startup script contents:"
        echo "──────────────────────────────────────"
        cat "$MESH_SCRIPT" 2>/dev/null || echo "Script not found"
        echo ""

        echo "════════════════════════════════════════════════════════════"
    } > "$DIAG_LOG"

    print_success "Diagnostics saved to: $DIAG_LOG"

    # Copy to USB if available
    if [ -d "/mnt/usb/ft_usb_build" ]; then
        USB_LOG="/mnt/usb/ft_usb_build/phase4_failure_$(date +%Y%m%d_%H%M%S).log"
        cp "$DIAG_LOG" "$USB_LOG" 2>/dev/null
        print_success "Diagnostics copied to USB: $(basename $USB_LOG)"
    fi

    echo ""
    print_info "Review diagnostics at: $DIAG_LOG"
    echo ""
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Manual test failed. Please resolve issues before continuing."
    echo ""
    print_info "Common issues and fixes:"
    echo "  1. RF-kill blocking WiFi:"
    echo "     sudo rfkill unblock wifi"
    echo "  2. NetworkManager interference:"
    echo "     sudo systemctl stop NetworkManager"
    echo "  3. Review diagnostic log above for details"
    echo ""
    exit 1
fi

################################################################################
# Step 7: Create Systemd Service
################################################################################

echo "Step 7: Creating Systemd Service..."
echo "------------------------------------"

SERVICE_FILE="/etc/systemd/system/batman-mesh.service"

print_info "Creating $SERVICE_FILE"

sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=BATMAN-adv Mesh Network
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start-batman-mesh.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if [ $? -eq 0 ]; then
    print_success "Service file created"
else
    print_error "Failed to create service file"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 8: Enable Service
################################################################################

echo "Step 8: Enabling Service..."
echo "---------------------------"

print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

print_info "Enabling batman-mesh.service..."
if sudo systemctl enable batman-mesh.service; then
    print_success "Service enabled (will start on boot)"
else
    print_error "Failed to enable service"
    ERRORS=$((ERRORS + 1))
fi

echo ""

print_info "Checking service status..."
sudo systemctl status batman-mesh.service --no-pager | head -n 10

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Configuration Summary"
echo "==============================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "BATMAN mesh network configured successfully!"
    echo ""
    print_info "Configuration created:"
    echo "  • Mesh script: $MESH_SCRIPT"
    echo "  • Service: $SERVICE_FILE"
    echo ""
    print_info "Mesh configuration:"
    echo "  • Interface: $MESH_IFACE (wlan0)"
    echo "  • bat0 IP: $MESH_IP"
    echo "  • SSID: $MESH_SSID"
    echo ""
    print_info "Current mesh status:"
    echo "  • bat0 is up and configured"
    echo "  • wlan0 in IBSS mode"
    echo "  • Service will auto-start on boot"
    echo ""
    print_warning "Note: Other devices (1-5) must join the same mesh SSID: $MESH_SSID"
    echo ""
    print_info "Ready to proceed to Phase 4 (DNS/DHCP)"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during configuration"
    echo ""
    print_warning "Please resolve issues before continuing"
    echo ""
    exit 1
fi
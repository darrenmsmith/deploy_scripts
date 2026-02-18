#!/bin/bash

################################################################################
# Phase 2: Internet Connection (STATIC IP FOR INSTALLATION)
# Uses static IP to avoid dhcpcd issues entirely
# After installation, reboot will use DHCP via systemd service
################################################################################

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

init_logging 2 "internet"
log_phase_start 2 "Internet Connection (wlan1)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "  $1"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

ERRORS=0

DIAG_SCRIPT="${SCRIPT_DIR}/../scripts/diagnose_phase2.sh"
DIAG_LOG_DIR="/mnt/usb/install_logs"

offer_diagnostics() {
    local reason="$1"
    echo ""
    print_error "Phase 2 failed: $reason"
    echo ""
    read -p "  Run diagnose_phase2.sh now to capture details? (y/n): " run_diag
    if [[ "$run_diag" =~ ^[Yy]$ ]]; then
        if [ -f "$DIAG_SCRIPT" ]; then
            echo ""
            print_info "Running diagnostics..."
            sudo bash "$DIAG_SCRIPT"
            echo ""
            print_info "Results saved to:"
            echo "  ${DIAG_LOG_DIR}/phase2_diagnostic_latest.log"
            echo ""
            print_info "Move USB to Dev system and open that file to review with Claude."
        else
            print_error "Diagnostic script not found: $DIAG_SCRIPT"
        fi
    else
        echo ""
        print_info "Diagnostic log location (if run manually):"
        echo "  ${DIAG_LOG_DIR}/phase2_diagnostic_latest.log"
        print_info "Run manually: sudo bash $DIAG_SCRIPT"
    fi
    echo ""
}

echo "Phase 2: Internet Connection (STATIC IP)"
echo "==========================================="
echo ""
echo "This phase uses STATIC IP to avoid dhcpcd dying."
echo "After installation, reboot will use DHCP."
echo ""

################################################################################
# Step 1: Clean Start
################################################################################

echo "Step 1: Preparing Interface..."
echo "------------------------------"

# Kill everything
sudo killall -9 wpa_supplicant 2>/dev/null
sudo killall -9 dhcpcd 2>/dev/null
sleep 2

# Reset wlan1
sudo ip link set wlan1 down
sudo ip addr flush dev wlan1
sleep 2
sudo ip link set wlan1 up
sleep 2

print_success "Interface ready"
echo ""

################################################################################
# Step 2: WiFi Configuration
################################################################################

echo "Step 2: WiFi Configuration..."
echo "-----------------------------"

read -p "Enter WiFi SSID: " WIFI_SSID
read -sp "Enter WiFi Password: " WIFI_PASSWORD
echo ""

# Create wpa_supplicant config
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"

sudo tee "$WPA_CONF" > /dev/null << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF

sudo chmod 600 "$WPA_CONF"
print_success "WiFi config created"
echo ""

################################################################################
# Step 3: Connect to WiFi
################################################################################

echo "Step 3: Connecting to WiFi..."
echo "-----------------------------"

sudo wpa_supplicant -B -i wlan1 -c "$WPA_CONF"
print_info "Waiting for WiFi connection (20 seconds)..."
sleep 20

if sudo wpa_cli -i wlan1 status | grep -q "wpa_state=COMPLETED"; then
    print_success "Connected to WiFi"
else
    offer_diagnostics "wpa_supplicant failed to connect to WiFi"
    exit 1
fi

echo ""

################################################################################
# Step 4: Set Static IP
################################################################################

echo "Step 4: Configuring Static IP..."
echo "---------------------------------"

print_warning "Enter network settings for your WiFi network:"
echo ""
read -p "Static IP for this Pi (e.g., 10.0.0.200): " STATIC_IP
read -p "Subnet mask (e.g., 255.255.255.0): " NETMASK
read -p "Gateway (your router, e.g., 10.0.0.1): " GATEWAY
read -p "DNS server (e.g., 8.8.8.8): " DNS

# Convert netmask to CIDR (simple cases)
case $NETMASK in
    255.255.255.0) CIDR=24 ;;
    255.255.0.0) CIDR=16 ;;
    255.255.255.255) CIDR=32 ;;
    *) CIDR=24 ;;  # Default
esac

# Set static IP
sudo ip addr add ${STATIC_IP}/${CIDR} dev wlan1
sudo ip route add default via $GATEWAY dev wlan1

# Set DNS
echo "nameserver $DNS" | sudo tee /etc/resolv.conf > /dev/null

print_success "Static IP configured"
print_info "IP: $STATIC_IP/$CIDR"
print_info "Gateway: $GATEWAY"
print_info "DNS: $DNS"

echo ""

################################################################################
# Step 5: Verify Internet
################################################################################

echo "Step 5: Verifying Internet..."
echo "-----------------------------"

sleep 5

if ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
    print_success "Internet working!"
else
    print_info "Check your network settings and try again"
    offer_diagnostics "internet ping to 8.8.8.8 failed (check static IP/gateway)"
    exit 1
fi

if host google.com &>/dev/null; then
    print_success "DNS working!"
else
    offer_diagnostics "DNS resolution failed"
    exit 1
fi

echo ""

################################################################################
# Step 6: Create Proper DHCP Service for Post-Reboot
################################################################################

echo "Step 6: Creating Service for Post-Reboot..."
echo "--------------------------------------------"

# Create simple service for after reboot
sudo tee /etc/systemd/system/wlan1-internet.service > /dev/null << 'EOF'
[Unit]
Description=wlan1 Internet Connection
After=network.target
Before=multi-user.target

[Service]
Type=simple
ExecStartPre=/usr/sbin/rfkill unblock wifi
ExecStartPre=/sbin/ip link set wlan1 up
ExecStartPre=/bin/sleep 5
ExecStart=/usr/sbin/wpa_supplicant -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create dhcpcd hook to start after wpa_supplicant
sudo tee /etc/systemd/system/wlan1-dhcp.service > /dev/null << 'EOF'
[Unit]
Description=DHCP for wlan1
After=wlan1-internet.service
Requires=wlan1-internet.service

[Service]
Type=forking
PIDFile=/run/dhcpcd-wlan1.pid
ExecStart=/usr/sbin/dhcpcd -4 -q -w wlan1
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wlan1-internet.service
sudo systemctl enable wlan1-dhcp.service

print_success "Services created for post-reboot"
print_info "After installation, reboot to use DHCP"

echo ""

################################################################################
# Done
################################################################################

echo "========================================"
echo "Phase 2 Complete"
echo "========================================"
echo ""

print_success "wlan1 connected with static IP"
echo ""
print_info "Configuration:"
echo "  • Interface: wlan1"
echo "  • SSID: $WIFI_SSID"
echo "  • Static IP: $STATIC_IP"
echo "  • Gateway: $GATEWAY"
echo ""
print_warning "IMPORTANT: This uses static IP for installation only"
print_info "After Phase 7, REBOOT to use DHCP automatically"
echo ""

log_phase_complete 2
exit 0

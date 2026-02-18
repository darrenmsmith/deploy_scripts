#!/bin/bash

################################################################################
# Phase 2: Internet Connection - FINAL FIX
# Key insight: dhcpcd must be a monitored systemd service, not ExecStartPost
################################################################################

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

init_logging 2 "internet"
log_phase_start 2 "Internet Connection (wlan1)"

# Load existing Phase 2 to reuse WiFi setup, just change dhcpcd handling
# Run original Phase 2 up to but not including the problematic dhcpcd/service parts

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
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

echo "Phase 2: Internet Connection (DHCPCD SERVICE FIX)"
echo "=================================================="
echo ""

################################################################################
# CREATE TWO SEPARATE SERVICES
################################################################################

# Service 1: wlan1-wpa (just handles wpa_supplicant)
sudo tee /etc/systemd/system/wlan1-wpa.service > /dev/null << 'EOF'
[Unit]
Description=wlan1 WPA Supplicant
After=network-pre.target
Before=network.target wlan1-dhcp.service
Wants=network-pre.target

[Service]
Type=forking
PIDFile=/var/run/wpa_supplicant-wlan1.pid

ExecStartPre=/usr/sbin/rfkill unblock wifi
ExecStartPre=/sbin/ip link set wlan1 down
ExecStartPre=/sbin/ip addr flush dev wlan1
ExecStartPre=/sbin/ip link set wlan1 up
ExecStartPre=/bin/sleep 3

ExecStart=/usr/sbin/wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant/wpa_supplicant-wlan1.conf -P /var/run/wpa_supplicant-wlan1.pid

ExecStop=/usr/bin/killall wpa_supplicant

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Service 2: wlan1-dhcp (handles dhcpcd, depends on wpa)
sudo tee /etc/systemd/system/wlan1-dhcp.service > /dev/null << 'EOF'
[Unit]
Description=wlan1 DHCP Client
After=wlan1-wpa.service
Requires=wlan1-wpa.service
Before=network-online.target

[Service]
Type=forking
PIDFile=/run/dhcpcd-wlan1.pid

# Wait for wpa_supplicant to connect
ExecStartPre=/bin/sleep 15

# Start dhcpcd with explicit PID file
ExecStart=/usr/sbin/dhcpcd -4 -q -b wlan1

ExecStop=/usr/bin/killall dhcpcd

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

print_success "Created two-service architecture"

# Reload systemd
sudo systemctl daemon-reload

# Enable both services
sudo systemctl enable wlan1-wpa.service
sudo systemctl enable wlan1-dhcp.service

print_success "Services enabled"

echo ""
print_info "Now configure WiFi and start services..."
echo ""

# Get WiFi credentials
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
print_success "WiFi configured"

echo ""

# Start the services
print_info "Starting wlan1-wpa.service..."
sudo systemctl start wlan1-wpa.service
sleep 10

if systemctl is-active --quiet wlan1-wpa.service; then
    print_success "wpa service active"
else
    sudo systemctl status wlan1-wpa.service --no-pager | head -20
    offer_diagnostics "wlan1-wpa.service failed to start"
    exit 1
fi

print_info "Starting wlan1-dhcp.service..."
sudo systemctl start wlan1-dhcp.service
sleep 20

if systemctl is-active --quiet wlan1-dhcp.service; then
    print_success "dhcp service active"
else
    sudo systemctl status wlan1-dhcp.service --no-pager | head -20
    offer_diagnostics "wlan1-dhcp.service failed to start"
    exit 1
fi

echo ""

# Verify IP
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)

if [ -n "$WLAN1_IP" ]; then
    print_success "IP obtained: $WLAN1_IP"
else
    offer_diagnostics "wlan1 did not obtain an IP address"
    exit 1
fi

# Verify internet
if ping -c 3 8.8.8.8 &>/dev/null; then
    print_success "Internet working!"
else
    offer_diagnostics "internet ping to 8.8.8.8 failed"
    exit 1
fi

echo ""
echo "========================================"
echo "Phase 2 Complete"
echo "========================================"
echo ""
print_success "wlan1 connected via two-service architecture"
echo ""
print_info "Services:"
echo "  • wlan1-wpa.service: Manages WiFi connection"
echo "  • wlan1-dhcp.service: Manages DHCP (auto-restart)"
echo "  • IP: $WLAN1_IP"
echo ""

log_phase_complete 2
exit 0

#!/bin/bash

################################################################################
# Phase 2: Internet Connection (ULTRA-SIMPLE - NO SYSTEMD)
# Just get wlan1 working for Phases 2-3, that's it
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

echo "Phase 2: Internet Connection (ULTRA-SIMPLE)"
echo "============================================"
echo ""
echo "This phase gets wlan1 working for installation only."
echo "Proper systemd service will be configured for post-reboot."
echo ""

################################################################################
# Step 1: Clean Start
################################################################################

echo "Step 1: Clean Start..."
echo "----------------------"

# Kill everything
print_info "Killing old processes..."
sudo killall -9 wpa_supplicant 2>/dev/null
sudo killall -9 dhcpcd 2>/dev/null
sleep 2

# Bring wlan1 down and up
print_info "Resetting wlan1..."
sudo ip link set wlan1 down
sudo ip addr flush dev wlan1
sleep 2
sudo ip link set wlan1 up
sleep 2

print_success "Clean state"

echo ""

################################################################################
# Step 2: Get WiFi Credentials
################################################################################

echo "Step 2: WiFi Configuration..."
echo "-----------------------------"

read -p "Enter WiFi SSID: " WIFI_SSID
read -sp "Enter WiFi Password: " WIFI_PASSWORD
echo ""

# Create wpa_supplicant config
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
print_info "Creating wpa_supplicant config..."

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
print_success "Config created"

echo ""

################################################################################
# Step 3: Start wpa_supplicant
################################################################################

echo "Step 3: Connecting to WiFi..."
echo "-----------------------------"

print_info "Starting wpa_supplicant..."
sudo wpa_supplicant -B -i wlan1 -c "$WPA_CONF"

print_info "Waiting for connection (20 seconds)..."
sleep 20

# Check connection
if sudo wpa_cli -i wlan1 status | grep -q "wpa_state=COMPLETED"; then
    SSID=$(sudo wpa_cli -i wlan1 status | grep "^ssid=" | cut -d'=' -f2)
    print_success "Connected to: $SSID"
else
    ERRORS=$((ERRORS + 1))
    offer_diagnostics "wpa_supplicant failed to connect to WiFi"
    exit 1
fi

echo ""

################################################################################
# Step 4: Get IP Address
################################################################################

echo "Step 4: Getting IP Address..."
echo "-----------------------------"

print_info "Starting dhcpcd..."

# Start dhcpcd in FOREGROUND mode with timeout
sudo timeout 60 dhcpcd -4 -w wlan1 &
DHCPCD_PID=$!

print_info "Waiting for IP (30 seconds)..."
sleep 30

# Check IP
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)

if [ -n "$WLAN1_IP" ]; then
    print_success "IP obtained: $WLAN1_IP"
else
    ERRORS=$((ERRORS + 1))
    offer_diagnostics "wlan1 did not obtain an IP address"
    exit 1
fi

# Check dhcpcd is still running
if ps -p $DHCPCD_PID > /dev/null 2>&1 || pgrep -f "dhcpcd.*wlan1" >/dev/null; then
    print_success "dhcpcd running"
else
    print_warning "dhcpcd exited - restarting in background..."
    sudo dhcpcd -4 wlan1 &
    sleep 5
fi

echo ""

################################################################################
# Step 5: Start Background Keepalive
################################################################################

echo "Step 5: Starting Connection Keepalive..."
echo "-----------------------------------------"

# Create keepalive script that runs during Phases 2-3
sudo tee /tmp/wlan1_keepalive.sh > /dev/null << 'KEEPALIVE'
#!/bin/bash
while true; do
    sleep 10

    # Check if dhcpcd is running
    if ! pgrep -f "dhcpcd.*wlan1" >/dev/null; then
        logger "PHASE2 KEEPALIVE: dhcpcd died, restarting"
        dhcpcd -4 wlan1 &
    fi

    # Check if we have IP
    if ! ip addr show wlan1 | grep -q "inet "; then
        logger "PHASE2 KEEPALIVE: No IP, restarting dhcpcd"
        killall dhcpcd 2>/dev/null
        sleep 2
        dhcpcd -4 wlan1 &
    fi
done
KEEPALIVE

sudo chmod +x /tmp/wlan1_keepalive.sh

# Start keepalive in background
sudo /tmp/wlan1_keepalive.sh &
KEEPALIVE_PID=$!

print_success "Keepalive started (PID: $KEEPALIVE_PID)"
print_info "Keepalive will monitor connection during Phases 2-3"

# Save PID for Phase 3 to stop later
echo "$KEEPALIVE_PID" > /tmp/wlan1_keepalive.pid

echo ""

################################################################################
# Step 6: Verify Internet
################################################################################

echo "Step 6: Verifying Internet..."
echo "-----------------------------"

if ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
    print_success "Internet working!"
else
    ERRORS=$((ERRORS + 1))
    offer_diagnostics "internet ping to 8.8.8.8 failed"
    exit 1
fi

if host google.com &>/dev/null; then
    print_success "DNS working!"
else
    print_warning "DNS may have issues"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "========================================"
echo "Phase 2 Complete"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "wlan1 connected and keepalive running"
    echo ""
    print_info "Configuration:"
    echo "  • Interface: wlan1"
    echo "  • SSID: $WIFI_SSID"
    echo "  • IP: $WLAN1_IP"
    echo "  • Keepalive PID: $KEEPALIVE_PID"
    echo ""
    print_warning "NOTE: This is temporary for installation only"
    print_info "After Phase 7, reboot to use proper systemd service"
    echo ""

    log_phase_complete 2
    exit 0
else
    offer_diagnostics "Phase 2 completed with $ERRORS errors"
    log_phase_failed 2 "Failed with $ERRORS errors"
    exit 1
fi

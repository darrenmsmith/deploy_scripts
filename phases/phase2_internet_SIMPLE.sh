#!/bin/bash

################################################################################
# Phase 2: Internet Connection (ULTRA-SIMPLE VERSION)
# Uses NetworkManager - the way Debian wants it
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

ERRORS=0

echo "Phase 2: Internet Connection (SIMPLE)"
echo "======================================"
echo ""
echo "This phase uses NetworkManager (Debian default) instead of fighting it."
echo ""

################################################################################
# Step 1: Check Prerequisites
################################################################################

echo "Step 1: Checking Prerequisites..."
echo "----------------------------------"

# Check NetworkManager
if command -v nmcli &>/dev/null; then
    print_success "NetworkManager found"
else
    print_error "NetworkManager not found - installing..."
    sudo apt-get update
    sudo apt-get install -y network-manager
fi

# Check wlan1 exists
if ip link show wlan1 &>/dev/null; then
    print_success "wlan1 interface found"
else
    print_error "wlan1 not found"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

echo ""

################################################################################
# Step 2: Configure WiFi via NetworkManager
################################################################################

echo "Step 2: Configuring WiFi..."
echo "---------------------------"

# Prompt for WiFi credentials
read -p "Enter WiFi SSID: " WIFI_SSID
read -sp "Enter WiFi Password: " WIFI_PASSWORD
echo ""

# Remove any existing connection
sudo nmcli connection delete "$WIFI_SSID" 2>/dev/null

# Create new connection
print_info "Creating NetworkManager connection..."
if sudo nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" ifname wlan1; then
    print_success "Connected to $WIFI_SSID"
else
    print_error "Failed to connect"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

echo ""

################################################################################
# Step 3: Verify Connection
################################################################################

echo "Step 3: Verifying Connection..."
echo "--------------------------------"

sleep 10

# Check IP
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)
if [ -n "$WLAN1_IP" ]; then
    print_success "IP obtained: $WLAN1_IP"
else
    print_error "No IP address"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

# Check internet
if ping -c 3 8.8.8.8 &>/dev/null; then
    print_success "Internet working"
else
    print_error "No internet"
    ERRORS=$((ERRORS + 1))
    exit 1
fi

echo ""

################################################################################
# Done
################################################################################

if [ $ERRORS -eq 0 ]; then
    print_success "Phase 2 complete!"
    log_phase_complete 2
    exit 0
else
    print_error "Phase 2 failed with $ERRORS errors"
    log_phase_failed 2 "Failed with $ERRORS errors"
    exit 1
fi

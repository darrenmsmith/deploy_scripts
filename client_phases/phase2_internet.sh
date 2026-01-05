#!/bin/bash

################################################################################
# Field Trainer - Client Phase 2: Internet Connection (USB WiFi)
# Temporary internet connection for package installation
# Uses USB WiFi adapter (wlan1) - will be disconnected after Phase 3
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

log_start "Client Phase 2: Internet Connection (USB WiFi)"

################################################################################
# Step 1: Check for USB WiFi Adapter (wlan1)
################################################################################

log_step "Checking for USB WiFi adapter"

if ip link show wlan1 &>/dev/null; then
    log_success "Found wlan1 (USB WiFi adapter)"
else
    log_error "No USB WiFi adapter (wlan1) detected!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "USB WiFi adapter required for internet access"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Please:"
    echo "  1. Connect USB hub to Pi Zero W"
    echo "  2. Plug in USB WiFi adapter"
    echo "  3. Wait 5 seconds for detection"
    echo "  4. Run this phase again"
    echo ""
    exit 1
fi

################################################################################
# Step 2: Get WiFi Credentials
################################################################################

log_step "WiFi credentials required for temporary internet access"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "WiFi Configuration (Temporary - for package installation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This connection will be used only for downloading packages"
echo "The USB WiFi adapter will be removed after Phase 3"
echo ""

read -p "Enter WiFi SSID: " WIFI_SSID

if [ -z "$WIFI_SSID" ]; then
    log_error "WiFi SSID cannot be empty"
    exit 1
fi

read -sp "Enter WiFi password: " WIFI_PASSWORD
echo ""

if [ -z "$WIFI_PASSWORD" ]; then
    log_error "WiFi password cannot be empty"
    exit 1
fi

log_success "WiFi credentials entered"

################################################################################
# Step 3: Clean Up Existing Connections
################################################################################

log_step "Cleaning up existing WiFi processes"

# Kill any existing wpa_supplicant processes
sudo killall wpa_supplicant 2>/dev/null || true
sudo killall dhcpcd 2>/dev/null || true
sleep 2

# Remove stale control interface files
sudo rm -rf /var/run/wpa_supplicant/* 2>/dev/null || true

log_success "Cleanup complete"

################################################################################
# Step 4: Create WPA Supplicant Configuration
################################################################################

log_step "Creating WiFi configuration for wlan1"

WPA_CONF="/tmp/wpa_wlan1.conf"

cat > "$WPA_CONF" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="${WIFI_SSID}"
    psk="${WIFI_PASSWORD}"
    key_mgmt=WPA-PSK
}
EOF

log_success "WiFi configuration created"

################################################################################
# Step 5: Connect to WiFi
################################################################################

log_step "Connecting to ${WIFI_SSID}..."

# Unblock WiFi
sudo rfkill unblock wifi
sleep 1

# Bring up wlan1
sudo ip link set wlan1 up
sleep 2

# Start wpa_supplicant
sudo wpa_supplicant -B -i wlan1 -c "$WPA_CONF"

if [ $? -eq 0 ]; then
    log_success "wpa_supplicant started"
else
    log_error "Failed to start wpa_supplicant"
    exit 1
fi

# Wait for connection
log_info "Waiting for WiFi association..."
sleep 10

# Check if connected
if sudo iw dev wlan1 link | grep -q "Connected"; then
    log_success "WiFi associated"
else
    log_error "WiFi association failed"
    log_info "Check WiFi credentials and try again"
    exit 1
fi

################################################################################
# Step 6: Get IP Address via DHCP
################################################################################

log_step "Requesting IP address via DHCP"

sudo dhcpcd wlan1

log_info "Waiting for IP assignment..."
sleep 5

# Check if we got an IP
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}')

if [ -n "$WLAN1_IP" ]; then
    log_success "IP address assigned: $WLAN1_IP"
else
    log_error "Failed to get IP address"
    echo ""
    echo "Troubleshooting:"
    echo "  - Verify WiFi credentials are correct"
    echo "  - Check if router is assigning DHCP addresses"
    echo "  - Ensure WiFi network '${WIFI_SSID}' is in range"
    echo ""
    exit 1
fi

################################################################################
# Step 7: Test Internet Connectivity
################################################################################

log_step "Testing internet connectivity"

if ping -c 3 -W 5 8.8.8.8 &>/dev/null; then
    log_success "Internet connection verified (ping 8.8.8.8)"
else
    log_error "Cannot reach internet"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check router internet connection"
    echo "  - Try: ping -c 3 192.168.1.1 (your router)"
    echo "  - Check firewall settings"
    echo ""
    exit 1
fi

# Test DNS resolution
if ping -c 2 -W 5 google.com &>/dev/null; then
    log_success "DNS resolution working"
else
    log_warning "DNS resolution failed (may still work)"
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Internet Connection Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Interface: wlan1 (USB WiFi)"
echo "  Network: $WIFI_SSID"
echo "  IP Address: $WLAN1_IP"
echo "  Status: Connected ✓"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Phase 2 complete!"

echo ""
echo "Ready for Phase 3: Package Installation"
echo ""
echo "NOTE: This internet connection is temporary"
echo "      USB WiFi adapter will be removed after Phase 3"
echo ""

# Clean up WPA config file
rm -f "$WPA_CONF"

log_end "Client Phase 2 complete"
exit 0

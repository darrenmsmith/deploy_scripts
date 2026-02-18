#!/bin/bash

################################################################################
# Field Trainer - Device Verification Script
# Run from Device0 to verify all field devices are online and functioning
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

clear

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     Field Trainer - System Verification Script           ║"
echo "║         Check all devices in mesh network                 ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# Step 1: Verify running on Device0
################################################################################

HOSTNAME=$(hostname)
if [[ ! $HOSTNAME =~ Device0 ]] && [[ ! $HOSTNAME =~ device0 ]]; then
    print_error "This script must be run from Device0 (gateway)"
    print_info "Current hostname: $HOSTNAME"
    exit 1
fi

print_success "Running on Device0"
echo ""

################################################################################
# Step 2: Check Device0 Services
################################################################################

print_header "════ Device0 (Gateway) Status ════"
echo ""

# Check mesh service
if systemctl is-active --quiet batman-mesh.service 2>/dev/null; then
    print_success "BATMAN mesh service running"
else
    print_error "BATMAN mesh service NOT running"
    echo "  Start with: sudo systemctl start batman-mesh"
fi

# Check DNS/DHCP
if systemctl is-active --quiet dnsmasq.service 2>/dev/null; then
    print_success "DNS/DHCP service running"
else
    print_warning "DNS/DHCP service not running"
fi

# Check Field Trainer app
if systemctl is-active --quiet field-trainer.service 2>/dev/null; then
    print_success "Field Trainer application running"

    # Check ports
    if netstat -tlnp 2>/dev/null | grep -q ":5000"; then
        print_success "Web interface available on port 5000"
    else
        print_warning "Web interface port 5000 not listening"
    fi

    if netstat -tlnp 2>/dev/null | grep -q ":6000"; then
        print_success "Field device server running on port 6000"
    else
        print_warning "Field device server port 6000 not listening"
    fi
else
    print_error "Field Trainer application NOT running"
fi

# Check bat0 interface
if ip addr show bat0 &>/dev/null; then
    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
    print_success "bat0 interface up: $BAT0_IP"
else
    print_error "bat0 interface not found"
fi

echo ""

################################################################################
# Step 3: Check Mesh Neighbors
################################################################################

print_header "════ Mesh Network Neighbors ════"
echo ""

if command -v batctl &> /dev/null; then
    NEIGHBORS=$(sudo batctl n 2>/dev/null)

    if echo "$NEIGHBORS" | grep -q "No batman"; then
        print_warning "No mesh neighbors detected"
    else
        echo "$NEIGHBORS"
    fi
else
    print_error "batctl not installed"
fi

echo ""

################################################################################
# Step 4: Check Each Field Device
################################################################################

print_header "════ Field Devices Status ════"
echo ""

DEVICE_COUNT=0
DEVICE_ONLINE=0

for i in {1..5}; do
    DEVICE_IP="192.168.99.10${i}"
    DEVICE_NAME="Device${i}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Checking $DEVICE_NAME ($DEVICE_IP)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    DEVICE_COUNT=$((DEVICE_COUNT + 1))

    # Ping test
    if ping -c 2 -W 3 $DEVICE_IP &>/dev/null; then
        print_success "Ping successful"
        DEVICE_ONLINE=$((DEVICE_ONLINE + 1))

        # SSH test (check if client service is running)
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no pi@$DEVICE_IP "systemctl is-active --quiet field-client.service" 2>/dev/null; then
            print_success "Client service running"
        else
            print_warning "Client service not running (or SSH failed)"
        fi

        # Get MAC address
        MAC=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no pi@$DEVICE_IP "cat /sys/class/net/wlan0/address" 2>/dev/null)
        if [ -n "$MAC" ]; then
            print_info "MAC: $MAC"
        fi

        # Get uptime
        UPTIME=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no pi@$DEVICE_IP "uptime -p" 2>/dev/null)
        if [ -n "$UPTIME" ]; then
            print_info "Uptime: $UPTIME"
        fi

    else
        print_error "Offline (no ping response)"
        print_info "Check if device is powered on and mesh is configured"
    fi

    echo ""
done

################################################################################
# Summary
################################################################################

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Verification Summary                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total Field Devices: 5"
echo "  Online: $DEVICE_ONLINE"
echo "  Offline: $((5 - DEVICE_ONLINE))"
echo ""

if [ $DEVICE_ONLINE -eq 5 ]; then
    print_success "All devices online and ready!"
elif [ $DEVICE_ONLINE -eq 0 ]; then
    print_error "No devices online"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify mesh network is active: sudo batctl n"
    echo "  2. Check Device0 mesh service: sudo systemctl status batman-mesh"
    echo "  3. Power cycle field devices"
    echo "  4. Check mesh SSID matches on all devices"
else
    print_warning "Some devices offline ($DEVICE_ONLINE/5 online)"
    echo ""
    echo "Check offline devices:"
    echo "  - Power and connectivity"
    echo "  - Mesh configuration (sudo batctl n on device)"
    echo "  - Service status (sudo systemctl status batman-mesh-client)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Additional Tests:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Web Interface:       http://192.168.99.100:5000"
echo "View device list:    http://192.168.99.100:5000/coach"
echo "Check logs:          sudo journalctl -u field-trainer -f"
echo "View mesh neighbors: sudo batctl n"
echo ""
echo "Test LED/Touch/Audio:"
echo "  1. Go to web interface"
echo "  2. Deploy a test course"
echo "  3. Verify LED colors change on all devices"
echo "  4. Touch each device and verify detection"
echo "  5. Listen for audio feedback"
echo ""

#!/bin/bash

################################################################################
# WiFi Interface Verification Script
# Verifies wlan0 (onboard) and wlan1 (USB) are correctly configured
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

echo "=========================================="
echo "WiFi Interface Verification"
echo "=========================================="
echo ""

################################################################################
# Check Interface Existence
################################################################################

echo "Step 1: Checking WiFi Interfaces..."
echo "------------------------------------"

# Check wlan0
echo -n "  wlan0 (onboard WiFi)... "
if ip link show wlan0 &>/dev/null; then
    print_success "exists"
else
    print_error "NOT FOUND"
    echo "    Expected: Onboard WiFi for MESH network"
    ERRORS=$((ERRORS + 1))
fi

# Check wlan1
echo -n "  wlan1 (USB WiFi)... "
if ip link show wlan1 &>/dev/null; then
    print_success "exists"
else
    print_error "NOT FOUND"
    echo "    Expected: USB WiFi adapter for INTERNET connection"
    echo "    Action: Please plug in USB WiFi adapter"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Missing WiFi interfaces - cannot continue"
    exit 1
fi

################################################################################
# Verify Interface Types
################################################################################

echo "Step 2: Verifying Interface Types..."
echo "-------------------------------------"

# Check wlan0 is onboard (should be on mmc or sdio bus)
echo -n "  wlan0 type... "
WLAN0_PATH=$(readlink -f /sys/class/net/wlan0)
if echo "$WLAN0_PATH" | grep -q "mmc\|sdio"; then
    print_success "onboard (mmc/sdio bus)"
    print_info "    Path: $WLAN0_PATH"
else
    print_warning "NOT on mmc/sdio bus"
    print_info "    Path: $WLAN0_PATH"
    print_warning "    This may be a USB adapter on wlan0"
    echo ""
    read -p "    Continue anyway? (y/n): " cont
    if [[ ! $cont =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check wlan1 is USB
echo -n "  wlan1 type... "
WLAN1_PATH=$(readlink -f /sys/class/net/wlan1)
if echo "$WLAN1_PATH" | grep -q "usb"; then
    print_success "USB adapter"
    print_info "    Path: $WLAN1_PATH"
else
    print_warning "NOT on USB bus"
    print_info "    Path: $WLAN1_PATH"
    print_warning "    This may be onboard WiFi on wlan1"
    echo ""
    read -p "    Continue anyway? (y/n): " cont
    if [[ ! $cont =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

################################################################################
# Check Interface States
################################################################################

echo "Step 3: Checking Interface States..."
echo "-------------------------------------"

# wlan0 state
WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
echo "  wlan0 state: $WLAN0_STATE"

# wlan1 state
WLAN1_STATE=$(ip link show wlan1 | grep -oP 'state \K\w+')
echo "  wlan1 state: $WLAN1_STATE"

echo ""

################################################################################
# Check for Conflicts
################################################################################

echo "Step 4: Checking for Conflicts..."
echo "----------------------------------"

# Check if wlan0 has IP (shouldn't have one yet for mesh)
echo -n "  wlan0 IP address... "
WLAN0_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
if [ -z "$WLAN0_IP" ]; then
    print_success "none (correct for mesh config)"
else
    print_warning "HAS IP: $WLAN0_IP"
    echo "    wlan0 should NOT have IP before mesh config"
    echo "    It will get IP on bat0 interface after mesh setup"
fi

# Check if wlan1 has IP
echo -n "  wlan1 IP address... "
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | awk '{print $2}')
if [ -z "$WLAN1_IP" ]; then
    print_info "none (will get DHCP after Phase 2)"
else
    print_success "HAS IP: $WLAN1_IP"
    echo "    wlan1 already configured for internet"
fi

echo ""

# Check for wpa_supplicant processes
echo "  wpa_supplicant processes:"
if pgrep -a wpa_supplicant; then
    WPA_WLAN0=$(pgrep -a wpa_supplicant | grep wlan0 || echo "none")
    WPA_WLAN1=$(pgrep -a wpa_supplicant | grep wlan1 || echo "none")
    echo "    wlan0: $WPA_WLAN0"
    echo "    wlan1: $WPA_WLAN1"
else
    print_info "    No wpa_supplicant running"
fi

echo ""

# Check for dhcpcd processes
echo "  dhcpcd processes:"
if pgrep -a dhcpcd; then
    DHCP_WLAN0=$(pgrep -a dhcpcd | grep wlan0 || echo "none")
    DHCP_WLAN1=$(pgrep -a dhcpcd | grep wlan1 || echo "none")
    echo "    wlan0: $DHCP_WLAN0"
    echo "    wlan1: $DHCP_WLAN1"
else
    print_info "    No dhcpcd running"
fi

echo ""

################################################################################
# Check RF-Kill Status
################################################################################

echo "Step 5: Checking RF-Kill Status..."
echo "-----------------------------------"

if command -v rfkill &>/dev/null; then
    rfkill list wifi
    echo ""

    # Check if any WiFi is blocked
    if rfkill list wifi | grep -q "Soft blocked: yes"; then
        print_warning "WiFi is soft-blocked by rfkill"
        echo "    Run: sudo rfkill unblock wifi"
    elif rfkill list wifi | grep -q "Hard blocked: yes"; then
        print_error "WiFi is HARD-blocked by rfkill"
        echo "    Check hardware WiFi switch"
    else
        print_success "WiFi not blocked"
    fi
else
    print_info "rfkill command not found"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "All checks passed!"
    echo ""
    print_info "Configuration:"
    echo "  • wlan0 (onboard)  → MESH network (batman-adv)"
    echo "  • wlan1 (USB)      → INTERNET connection (DHCP)"
    echo ""
    print_info "Next steps:"
    echo "  1. Run Phase 2 (configure wlan1 for internet)"
    echo "  2. Run Phase 4 (configure wlan0 for mesh)"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s)"
    echo ""
    print_warning "Please resolve issues before continuing with build"
    echo ""
    exit 1
fi

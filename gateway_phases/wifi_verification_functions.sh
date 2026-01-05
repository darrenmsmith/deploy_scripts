#!/bin/bash

################################################################################
# WiFi Interface Verification Functions
# Shared functions for verifying wlan0 (mesh) and wlan1 (internet)
################################################################################

# Color codes (if not already defined)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

################################################################################
# verify_wifi_interfaces
# Verifies both wlan0 (onboard/mesh) and wlan1 (USB/internet) exist
################################################################################
verify_wifi_interfaces() {
    local ERRORS=0

    echo "Verifying WiFi Interfaces..."
    echo "-----------------------------"

    # Check wlan0 exists
    echo -n "  wlan0 (onboard WiFi for MESH)... "
    if ip link show wlan0 &>/dev/null; then
        print_success "exists"
    else
        print_error "NOT FOUND"
        echo "    Expected: Onboard WiFi interface for mesh network"
        ERRORS=$((ERRORS + 1))
    fi

    # Check wlan1 exists
    echo -n "  wlan1 (USB WiFi for INTERNET)... "
    if ip link show wlan1 &>/dev/null; then
        print_success "exists"
    else
        print_error "NOT FOUND"
        echo "    Expected: USB WiFi adapter for internet connection"
        print_warning "    Please ensure USB WiFi adapter is plugged in"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""

    if [ $ERRORS -gt 0 ]; then
        print_error "WiFi interface verification failed"
        return 1
    fi

    return 0
}

################################################################################
# verify_wlan0_type
# Verifies wlan0 is onboard (mmc/sdio bus)
################################################################################
verify_wlan0_type() {
    echo "Verifying wlan0 is onboard WiFi..."
    echo "-----------------------------------"

    local WLAN0_PATH=$(readlink -f /sys/class/net/wlan0 2>/dev/null)

    echo -n "  wlan0 bus type... "
    if echo "$WLAN0_PATH" | grep -q "mmc\|sdio"; then
        print_success "onboard (mmc/sdio)"
        print_info "  Path: $WLAN0_PATH"
        return 0
    else
        print_warning "NOT on mmc/sdio bus"
        print_warning "  Path: $WLAN0_PATH"
        print_warning "  wlan0 may be a USB adapter (expected: onboard)"
        echo ""
        read -p "  Continue anyway? (y/n): " cont < /dev/tty
        if [[ $cont =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

################################################################################
# verify_wlan1_type
# Verifies wlan1 is USB adapter
################################################################################
verify_wlan1_type() {
    echo "Verifying wlan1 is USB WiFi adapter..."
    echo "---------------------------------------"

    local WLAN1_PATH=$(readlink -f /sys/class/net/wlan1 2>/dev/null)

    echo -n "  wlan1 bus type... "
    if echo "$WLAN1_PATH" | grep -q "usb"; then
        print_success "USB adapter"
        print_info "  Path: $WLAN1_PATH"
        return 0
    else
        print_warning "NOT on USB bus"
        print_warning "  Path: $WLAN1_PATH"
        print_warning "  wlan1 may be onboard WiFi (expected: USB)"
        echo ""
        read -p "  Continue anyway? (y/n): " cont < /dev/tty
        if [[ $cont =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}

################################################################################
# verify_wlan1_internet
# Verifies wlan1 has internet connectivity (has IP, not 169.254.x.x)
################################################################################
verify_wlan1_internet() {
    echo "Verifying wlan1 internet connection..."
    echo "---------------------------------------"

    local ERRORS=0

    # Check interface exists
    echo -n "  wlan1 interface... "
    if ip link show wlan1 &>/dev/null; then
        local WLAN1_STATE=$(ip link show wlan1 | grep -o "state [A-Z]*" | awk '{print $2}')
        print_success "exists ($WLAN1_STATE)"
    else
        print_error "NOT FOUND"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for IP address
    echo -n "  wlan1 IP address... "
    local WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -n "$WLAN1_IP" ]; then
        print_success "$WLAN1_IP"
    else
        print_error "NO IP ADDRESS"
        print_warning "  wlan1 must be connected to internet before continuing"
        print_warning "  Please complete Phase 2 (Internet Connection) first"
        ERRORS=$((ERRORS + 1))
    fi

    # Test internet connectivity
    if [ $ERRORS -eq 0 ]; then
        echo -n "  Internet connectivity... "
        if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
            print_success "online"
        else
            print_warning "cannot reach 8.8.8.8"
            print_warning "  Internet connection may be limited"
        fi
    fi

    echo ""

    if [ $ERRORS -gt 0 ]; then
        return 1
    fi

    return 0
}

################################################################################
# verify_wlan0_available
# Verifies wlan0 is not being used by other services (ready for mesh)
################################################################################
verify_wlan0_available() {
    echo "Verifying wlan0 is available for mesh..."
    echo "-----------------------------------------"

    # Check if wlan0 has IP (it shouldn't before mesh config)
    echo -n "  wlan0 IP address... "
    local WLAN0_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
    if [ -z "$WLAN0_IP" ]; then
        print_success "none (correct - will use bat0 after mesh)"
    else
        print_warning "HAS IP: $WLAN0_IP"
        echo "    wlan0 should not have IP before mesh configuration"
        echo "    It will receive IP on bat0 interface after mesh setup"
        read -p "    Disconnect wlan0 and continue? (y/n): " disc < /dev/tty
        if [[ $disc =~ ^[Yy]$ ]]; then
            sudo ip addr flush dev wlan0
            sudo ip link set wlan0 down
            print_success "wlan0 disconnected"
        else
            return 1
        fi
    fi

    # Check for wpa_supplicant on wlan0
    echo -n "  wpa_supplicant on wlan0... "
    if pgrep -f "wpa_supplicant.*wlan0" >/dev/null; then
        print_warning "running (will be stopped for mesh)"
        sudo pkill -f "wpa_supplicant.*wlan0"
        print_success "stopped"
    else
        print_success "not running (correct)"
    fi

    echo ""
    return 0
}

################################################################################
# show_wifi_summary
# Display summary of WiFi configuration
################################################################################
show_wifi_summary() {
    echo ""
    echo "=========================================="
    echo "WiFi Interface Summary"
    echo "=========================================="
    echo ""
    print_info "Configuration:"
    echo "  • wlan0 (onboard)  → MESH network (batman-adv)"
    echo "  • wlan1 (USB)      → INTERNET connection (DHCP)"
    echo ""

    # Show current states
    if ip link show wlan0 &>/dev/null; then
        local WLAN0_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | awk '{print $2}')
        local WLAN0_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}' | head -1)
        echo "  wlan0: $WLAN0_STATE ${WLAN0_IP:-(no IP)}"
    fi

    if ip link show wlan1 &>/dev/null; then
        local WLAN1_STATE=$(ip link show wlan1 | grep -o "state [A-Z]*" | awk '{print $2}')
        local WLAN1_IP=$(ip addr show wlan1 | grep "inet " | awk '{print $2}' | head -1)
        echo "  wlan1: $WLAN1_STATE ${WLAN1_IP:-(no IP)}"
    fi

    echo ""
}

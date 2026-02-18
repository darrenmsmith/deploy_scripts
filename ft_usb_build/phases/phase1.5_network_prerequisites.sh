#!/bin/bash

################################################################################
# Phase 1.5: Network Prerequisites Check
# Ensures dhcpcd5 and wpasupplicant are available BEFORE Phase 2
################################################################################

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logging_functions.sh"

# Initialize logging
init_logging 1.5 "network_prerequisites"
log_phase_start 1.5 "Network Prerequisites Check"

ERRORS=0

echo "Phase 1.5: Network Prerequisites Check"
echo "======================================="
echo ""
echo "Checking for packages required by Phase 2 (Internet Connection):"
echo "  • wpasupplicant (WiFi authentication)"
echo "  • dhcpcd5 (DHCP client for IP address)"
echo ""

################################################################################
# Check for Critical Packages
################################################################################

echo "Checking installed packages..."
echo ""

# Check wpasupplicant
echo -n "  wpasupplicant... "
if dpkg -l 2>/dev/null | grep -q "^ii  wpasupplicant "; then
    WPA_VERSION=$(dpkg -l | grep "^ii  wpasupplicant " | awk '{print $3}')
    print_success "installed ($WPA_VERSION)"
    log_success "wpasupplicant is installed: $WPA_VERSION"
    HAS_WPA=true
else
    print_error "NOT INSTALLED"
    log_error "wpasupplicant is not installed"
    HAS_WPA=false
    ERRORS=$((ERRORS + 1))
fi

# Check dhcpcd5
echo -n "  dhcpcd5... "
if dpkg -l 2>/dev/null | grep -q "^ii  dhcpcd5 "; then
    DHCP_VERSION=$(dpkg -l | grep "^ii  dhcpcd5 " | awk '{print $3}')
    print_success "installed ($DHCP_VERSION)"
    log_success "dhcpcd5 is installed: $DHCP_VERSION"
    HAS_DHCP=true
else
    print_error "NOT INSTALLED"
    log_error "dhcpcd5 is not installed"
    HAS_DHCP=false
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Handle Missing Packages
################################################################################

if [ $ERRORS -eq 0 ]; then
    print_success "All network prerequisites are installed!"
    echo ""
    print_info "You can proceed to Phase 2 (Internet Connection)"
    log_phase_complete 1.5
    exit 0
fi

# Packages are missing - need to handle this
print_warning "Network prerequisites are MISSING!"
echo ""
print_info "Phase 2 requires these packages to configure WiFi."
echo ""

################################################################################
# Solution Options
################################################################################

echo "How to fix this:"
echo ""

# Check if offline packages exist
OFFLINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/offline_packages"

if [ -d "$OFFLINE_DIR" ] && [ "$(ls -A $OFFLINE_DIR/*.deb 2>/dev/null | wc -l)" -gt 0 ]; then
    print_info "OPTION 1: Install from offline packages on USB drive"
    echo ""
    echo "  Found offline packages directory with .deb files"
    echo ""
    read -p "  Install from offline packages now? (y/n): " install_offline

    if [[ "$install_offline" =~ ^[Yy]$ ]]; then
        log_step "Installing from offline packages"
        echo ""
        print_info "Installing offline packages..."

        # Install with --force-depends to avoid removal
        # We'll fix dependencies in Phase 3 when we have internet
        if sudo dpkg -i --force-depends $OFFLINE_DIR/*.deb 2>&1 | tee -a "$(get_log_file)"; then
            print_success "Offline packages installed"
            log_success "Offline packages installed successfully"
        else
            print_error "Offline installation failed"
            log_error "dpkg -i failed for offline packages"
        fi

        # Check again
        echo ""
        print_info "Verifying installation..."
        if dpkg -l | grep -q "^ii  wpasupplicant" && dpkg -l | grep -q "^ii  dhcpcd5"; then
            print_success "Network prerequisites now installed!"
            print_warning "Note: Some dependencies may be incomplete - will be fixed in Phase 3"
            log_success "wpasupplicant and dhcpcd5 installed (dependencies deferred to Phase 3)"
            log_phase_complete 1.5
            exit 0
        else
            print_error "Installation failed - packages still missing"
            log_error "Offline package installation failed"
            ERRORS=1
        fi
    fi
    echo ""
fi

# If we get here, offline didn't work or wasn't chosen
print_warning "Cannot proceed without wpasupplicant and dhcpcd5"
echo ""

print_info "SOLUTION: Use a different Raspberry Pi OS image"
echo ""
echo "Some minimal/lite OS images don't include network tools."
echo ""
echo "Recommended:"
echo "  1. Use 'Raspberry Pi OS with Desktop' (includes all network tools)"
echo "  2. OR manually install these packages first"
echo "  3. OR create offline_packages directory with ALL .deb files (including dependencies)"
echo ""

print_info "To download offline packages (on a computer with internet):"
echo "  mkdir -p /mnt/usb/ft_usb_build/offline_packages"
echo "  cd /mnt/usb/ft_usb_build/offline_packages"
echo "  apt download wpasupplicant dhcpcd5 dhcpcd iptables libip4tc2 libip6tc2 libxtables12 libnetfilter-conntrack3 libnfnetlink0"
echo "  # Copy these .deb files to USB drive"
echo ""

log_phase_failed 1.5 "Missing wpasupplicant and/or dhcpcd5"
echo "Log file: $(get_log_file)"
echo ""

exit 1

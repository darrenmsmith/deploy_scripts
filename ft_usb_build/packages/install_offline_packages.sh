#!/bin/bash

################################################################################
# Offline Package Installer
# Installs .deb packages from USB drive without internet
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

# Get script directory (where USB is mounted)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGES_DIR="$SCRIPT_DIR/debs"

echo "Offline Package Installer"
echo "========================="
echo ""

# Check if packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    print_error "Packages directory not found: $PACKAGES_DIR"
    print_info "Please create directory and add .deb files"
    exit 1
fi

# Count packages
PACKAGE_COUNT=$(ls -1 "$PACKAGES_DIR"/*.deb 2>/dev/null | wc -l)

if [ "$PACKAGE_COUNT" -eq 0 ]; then
    print_error "No .deb packages found in $PACKAGES_DIR"
    print_info "Please download packages first"
    exit 1
fi

print_info "Found $PACKAGE_COUNT packages in $PACKAGES_DIR"
echo ""

# Install all packages
print_info "Installing packages..."
echo ""

cd "$PACKAGES_DIR"

# Install with dpkg (ignores dependencies initially)
INSTALLED=0
FAILED=0

for deb in *.deb; do
    PACKAGE_NAME=$(dpkg-deb -f "$deb" Package 2>/dev/null)
    echo -n "  Installing $PACKAGE_NAME... "
    
    if sudo dpkg -i "$deb" 2>/dev/null; then
        print_success "done"
        INSTALLED=$((INSTALLED + 1))
    else
        print_warning "failed (may need dependencies)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""

# Fix broken dependencies (if any)
if [ $FAILED -gt 0 ]; then
    print_info "Fixing broken dependencies..."
    if sudo dpkg --configure -a 2>/dev/null; then
        print_success "Dependencies resolved"
    else
        print_warning "Some packages may have unmet dependencies"
        print_info "Run 'sudo apt --fix-broken install' when internet is available"
    fi
fi

echo ""
echo "==============================="
echo "Installation Summary"
echo "==============================="
echo ""
print_info "Packages installed: $INSTALLED"
if [ $FAILED -gt 0 ]; then
    print_warning "Packages with issues: $FAILED"
fi
echo ""

# Verify critical packages
print_info "Verifying critical packages..."

CRITICAL_PACKAGES=(
    "wpasupplicant"
    "dhcpcd5"
    "batctl"
    "dnsmasq"
    "iptables-persistent"
    "python3-flask"
    "python3-pil"
    "git"
)

MISSING=0

for package in "${CRITICAL_PACKAGES[@]}"; do
    echo -n "  $package... "
    if dpkg -l | grep -q "^ii  $package "; then
        print_success "✓"
    else
        print_error "✗ missing"
        MISSING=$((MISSING + 1))
    fi
done

echo ""

if [ $MISSING -eq 0 ]; then
    print_success "All critical packages installed!"
    echo ""
    print_info "You can now run Phase 1 and Phase 2"
    exit 0
else
    print_warning "$MISSING critical packages missing"
    echo ""
    print_info "Missing packages can be installed later when internet is available"
    print_info "Or download additional .deb files and re-run this script"
    exit 1
fi

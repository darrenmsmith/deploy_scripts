#!/bin/bash

################################################################################
# Diagnostic Script: Check Network and Package Manager Readiness
# Run this BEFORE Phase 1 to diagnose connectivity issues
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

echo "======================================="
echo "Network & Package Manager Diagnostics"
echo "======================================="
echo ""
echo "This script checks if your system is ready for Phase 1"
echo ""

ISSUES=0

################################################################################
# 1. Network Interfaces
################################################################################

echo "1. Network Interfaces"
echo "---------------------"

echo -n "  wlan0 (built-in WiFi)... "
if ip link show wlan0 &>/dev/null; then
    STATUS=$(ip link show wlan0 | grep -o "state [A-Z]*" | awk '{print $2}')
    print_success "$STATUS"
else
    print_warning "not found"
fi

echo -n "  wlan1 (USB WiFi)... "
if ip link show wlan1 &>/dev/null; then
    STATUS=$(ip link show wlan1 | grep -o "state [A-Z]*" | awk '{print $2}')
    WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -n "$WLAN1_IP" ]; then
        print_success "$STATUS with IP $WLAN1_IP"
    else
        print_warning "$STATUS but no IP address"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_error "not found"
    print_info "    Run Phase 2 first to configure wlan1"
    ISSUES=$((ISSUES + 1))
fi

echo ""

################################################################################
# 2. Internet Connectivity
################################################################################

echo "2. Internet Connectivity"
echo "------------------------"

echo -n "  Ping 8.8.8.8 (Google DNS)... "
if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    print_success "working"
else
    print_error "FAILED"
    print_info "    No IP connectivity - check wlan1 configuration"
    ISSUES=$((ISSUES + 1))
fi

echo -n "  Ping 1.1.1.1 (Cloudflare)... "
if ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
    print_success "working"
else
    print_error "FAILED"
    ISSUES=$((ISSUES + 1))
fi

echo ""

################################################################################
# 3. DNS Resolution
################################################################################

echo "3. DNS Resolution"
echo "-----------------"

echo "  Current /etc/resolv.conf:"
if [ -f /etc/resolv.conf ]; then
    cat /etc/resolv.conf | grep -v "^#" | grep -v "^$" | sed 's/^/    /'
    echo ""

    NAMESERVER_COUNT=$(grep -c "^nameserver" /etc/resolv.conf 2>/dev/null || echo 0)
    echo -n "  Nameservers configured... "
    if [ "$NAMESERVER_COUNT" -gt 0 ]; then
        print_success "$NAMESERVER_COUNT found"
    else
        print_error "NONE found"
        print_info "    This will cause DNS failures!"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_error "/etc/resolv.conf missing!"
    ISSUES=$((ISSUES + 1))
fi

echo -n "  Resolve google.com... "
if host google.com &>/dev/null || nslookup google.com &>/dev/null || getent hosts google.com &>/dev/null; then
    IP=$(getent hosts google.com 2>/dev/null | awk '{print $1}' | head -1)
    print_success "working ($IP)"
else
    print_error "FAILED"
    print_info "    DNS resolution not working"
    ISSUES=$((ISSUES + 1))
fi

echo -n "  Resolve deb.debian.org... "
if host deb.debian.org &>/dev/null || nslookup deb.debian.org &>/dev/null || getent hosts deb.debian.org &>/dev/null; then
    IP=$(getent hosts deb.debian.org 2>/dev/null | awk '{print $1}' | head -1)
    print_success "working ($IP)"
else
    print_error "FAILED"
    print_info "    Cannot reach Debian repositories"
    ISSUES=$((ISSUES + 1))
fi

echo ""

################################################################################
# 4. Package Manager
################################################################################

echo "4. Package Manager (apt)"
echo "------------------------"

echo "  /etc/apt/sources.list:"
if [ -f /etc/apt/sources.list ]; then
    REPO_COUNT=$(grep -c "^deb " /etc/apt/sources.list 2>/dev/null || echo 0)
    echo -n "    Repository lines... "
    if [ "$REPO_COUNT" -gt 0 ]; then
        print_success "$REPO_COUNT found"
        grep "^deb " /etc/apt/sources.list | head -3 | sed 's/^/      /'
    else
        print_error "NONE found"
        ISSUES=$((ISSUES + 1))
    fi
else
    print_error "/etc/apt/sources.list missing!"
    ISSUES=$((ISSUES + 1))
fi

echo ""

echo -n "  apt cache exists... "
if [ -d /var/lib/apt/lists ] && [ "$(ls -A /var/lib/apt/lists 2>/dev/null | wc -l)" -gt 5 ]; then
    print_success "yes"
else
    print_warning "empty or missing"
    print_info "    Run 'sudo apt update' first"
fi

echo -n "  dpkg functional... "
if dpkg --version &>/dev/null; then
    print_success "yes"
else
    print_error "FAILED"
    ISSUES=$((ISSUES + 1))
fi

echo ""

################################################################################
# 5. Critical Pre-existing Packages
################################################################################

echo "5. Critical Pre-existing Packages"
echo "-----------------------------------"

check_package() {
    local pkg=$1
    echo -n "  $pkg... "
    if dpkg -l | grep -q "^ii  $pkg "; then
        VERSION=$(dpkg -l | grep "^ii  $pkg " | awk '{print $3}' | cut -d: -f1)
        print_success "installed ($VERSION)"
        return 0
    else
        print_warning "not installed"
        return 1
    fi
}

check_package "wpasupplicant"
check_package "dhcpcd5"
check_package "python3"

# These are expected to be missing on fresh OS
echo ""
echo "  Packages expected to install in Phase 1:"
for pkg in git curl iptables python3-pip python3-flask; do
    echo -n "    $pkg... "
    if dpkg -l | grep -q "^ii  $pkg "; then
        print_info "already installed"
    else
        print_info "will install"
    fi
done

echo ""

################################################################################
# 6. System Information
################################################################################

echo "6. System Information"
echo "---------------------"

echo "  Hostname: $(hostname)"
echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Uptime: $(uptime -p)"
echo "  Free memory: $(free -h | grep Mem | awk '{print $4}')"

echo ""

################################################################################
# 7. Detailed Network Routes
################################################################################

echo "7. Detailed Network Routes"
echo "--------------------------"

echo "  Default gateway:"
ip route | grep default | sed 's/^/    /'

echo ""
echo "  All routes:"
ip route | sed 's/^/    /'

echo ""

################################################################################
# 8. DNS Server Connectivity
################################################################################

echo "8. DNS Server Connectivity"
echo "--------------------------"

for dns in 8.8.8.8 8.8.4.4 1.1.1.1; do
    echo -n "  Ping $dns... "
    if ping -c 1 -W 3 $dns &>/dev/null; then
        print_success "reachable"
    else
        print_error "FAILED"
        ISSUES=$((ISSUES + 1))
    fi
done

echo ""

################################################################################
# 9. Test Package Installation
################################################################################

echo "9. Test Package Installation (dry-run)"
echo "---------------------------------------"

echo "  Testing if apt can resolve dependencies..."
echo -n "    Dry-run: apt install -y curl... "
if sudo apt install -y --dry-run curl &>/dev/null; then
    print_success "would succeed"
else
    print_error "would FAIL"
    print_info "    Run 'sudo apt update' first"
    ISSUES=$((ISSUES + 1))
fi

echo ""

################################################################################
# Summary
################################################################################

echo "======================================="
echo "Diagnostic Summary"
echo "======================================="
echo ""

if [ $ISSUES -eq 0 ]; then
    print_success "All checks passed! System is ready for Phase 1"
    echo ""
    print_info "Next steps:"
    echo "  1. Run: sudo /mnt/usb/ft_usb_build/phases/phase1_packages.sh"
    echo ""
else
    print_warning "Found $ISSUES potential issue(s)"
    echo ""
    print_info "Common fixes:"
    echo ""

    if ! ip addr show wlan1 2>/dev/null | grep -q "inet "; then
        echo "  ⚠ wlan1 has no IP address"
        echo "    Fix: Run Phase 2 to configure internet"
        echo "    Command: sudo /mnt/usb/ft_usb_build/phases/phase2_internet.sh"
        echo ""
    fi

    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "  ⚠ No internet connectivity"
        echo "    Fix: Check wlan1 configuration"
        echo "    Command: sudo systemctl status wlan1-internet"
        echo "    Command: sudo systemctl restart wlan1-internet"
        echo ""
    fi

    if ! grep -q "^nameserver" /etc/resolv.conf 2>/dev/null; then
        echo "  ⚠ No DNS nameservers configured"
        echo "    Fix: Add Google DNS manually"
        echo "    Command: echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf"
        echo ""
    fi

    if ! host deb.debian.org &>/dev/null; then
        echo "  ⚠ Cannot resolve Debian repositories"
        echo "    Fix: Check DNS and wait for network to stabilize"
        echo "    Wait: 2-3 minutes after Phase 2"
        echo ""
    fi

    echo "  General troubleshooting:"
    echo "    • Wait 2-3 minutes after Phase 2 for network to stabilize"
    echo "    • Run: sudo apt update"
    echo "    • Check: cat /etc/resolv.conf"
    echo "    • Check: cat /etc/apt/sources.list"
    echo "    • Restart network: sudo systemctl restart wlan1-internet"
    echo ""

    read -p "Continue to Phase 1 anyway? (y/n): " continue_anyway
    if [[ "$continue_anyway" =~ ^[Yy]$ ]]; then
        print_warning "Proceeding despite issues..."
    else
        print_info "Fix issues first, then re-run diagnostics"
        exit 1
    fi
fi

echo ""
exit 0

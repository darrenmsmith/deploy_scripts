#!/bin/bash

################################################################################
# EMERGENCY: Restore Internet and SSH Connectivity
# Run this if Phase 5 caused you to lose internet or SSH access
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

echo "EMERGENCY: Restoring Connectivity"
echo "=================================="
echo ""
print_warning "This script will reset iptables to allow all traffic"
print_warning "Use this ONLY if you lost SSH or internet access"
echo ""
read -p "Press Enter to restore connectivity (or Ctrl+C to cancel)..."
echo ""

################################################################################
# Step 1: Set All Policies to ACCEPT
################################################################################

echo "Step 1: Setting all iptables policies to ACCEPT..."
echo "--------------------------------------------------"

if sudo iptables -P INPUT ACCEPT; then
    print_success "INPUT policy set to ACCEPT"
else
    print_error "Failed to set INPUT policy"
fi

if sudo iptables -P FORWARD ACCEPT; then
    print_success "FORWARD policy set to ACCEPT"
else
    print_error "Failed to set FORWARD policy"
fi

if sudo iptables -P OUTPUT ACCEPT; then
    print_success "OUTPUT policy set to ACCEPT"
else
    print_error "Failed to set OUTPUT policy"
fi

echo ""

################################################################################
# Step 2: Flush All Rules (Keep NAT)
################################################################################

echo "Step 2: Flushing INPUT and FORWARD rules..."
echo "--------------------------------------------"

if sudo iptables -F INPUT; then
    print_success "INPUT chain flushed"
else
    print_warning "Could not flush INPUT chain"
fi

if sudo iptables -F FORWARD; then
    print_success "FORWARD chain flushed"
else
    print_warning "Could not flush FORWARD chain"
fi

if sudo iptables -F OUTPUT; then
    print_success "OUTPUT chain flushed"
else
    print_warning "Could not flush OUTPUT chain"
fi

# Keep NAT rules (MASQUERADE needed for internet sharing)
print_info "Keeping NAT rules (MASQUERADE)"

echo ""

################################################################################
# Step 3: Restart wlan1 Connection
################################################################################

echo "Step 3: Restarting wlan1 internet connection..."
echo "------------------------------------------------"

# Restart wlan1-internet service
echo -n "  Restarting wlan1-internet service... "
if sudo systemctl restart wlan1-internet.service &>/dev/null; then
    print_success "restarted"
    sleep 5
else
    print_warning "service not found or failed"
fi

# Check if wlan1 has IP
WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')
if [ -n "$WLAN1_IP" ]; then
    print_success "wlan1 has IP: $WLAN1_IP"
else
    print_warning "wlan1 has no IP address"

    # Try manual restart
    print_info "Trying manual wlan1 restart..."
    sudo ip link set wlan1 down
    sleep 2
    sudo ip link set wlan1 up
    sleep 5
    sudo dhcpcd -4 wlan1 &>/dev/null &
    sleep 10

    WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')
    if [ -n "$WLAN1_IP" ]; then
        print_success "wlan1 recovered: $WLAN1_IP"
    else
        print_error "wlan1 still has no IP"
    fi
fi

echo ""

################################################################################
# Step 4: Re-add Essential Rules (Minimal)
################################################################################

echo "Step 4: Adding essential iptables rules..."
echo "-------------------------------------------"

# MASQUERADE for NAT
if ! sudo iptables -t nat -C POSTROUTING -o wlan1 -j MASQUERADE 2>/dev/null; then
    if sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE; then
        print_success "NAT: MASQUERADE on wlan1"
    else
        print_warning "Could not add MASQUERADE rule"
    fi
else
    print_info "NAT: MASQUERADE already exists"
fi

# FORWARD bat0 → wlan1
if sudo iptables -A FORWARD -i bat0 -o wlan1 -j ACCEPT 2>/dev/null; then
    print_success "FORWARD: bat0 → wlan1"
else
    print_info "FORWARD: bat0 → wlan1 may already exist"
fi

# FORWARD wlan1 → bat0 (established)
if sudo iptables -A FORWARD -i wlan1 -o bat0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    print_success "FORWARD: wlan1 → bat0 (established)"
elif sudo iptables -A FORWARD -i wlan1 -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    print_success "FORWARD: wlan1 → bat0 (established, conntrack)"
else
    print_info "FORWARD: wlan1 → bat0 may already exist"
fi

echo ""

################################################################################
# Step 5: Test Connectivity
################################################################################

echo "Step 5: Testing connectivity..."
echo "--------------------------------"

# Test internet
echo -n "  Internet (ping 8.8.8.8)... "
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    print_success "working"
else
    print_error "FAILED"
    print_info "Check wlan1 connection manually"
fi

# Check SSH
echo -n "  SSH daemon... "
if sudo systemctl is-active --quiet sshd || sudo systemctl is-active --quiet ssh; then
    print_success "running"
else
    print_warning "SSH may not be running"
fi

# Check wlan1
echo -n "  wlan1 interface... "
FINAL_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')
if [ -n "$FINAL_IP" ]; then
    print_success "UP with IP $FINAL_IP"
else
    print_error "DOWN or no IP"
fi

echo ""

################################################################################
# Step 6: Save Rules
################################################################################

echo "Step 6: Saving permissive rules..."
echo "-----------------------------------"

read -p "Save these permissive rules permanently? (y/n): " SAVE_RULES

if [[ "$SAVE_RULES" =~ ^[Yy]$ ]]; then
    sudo mkdir -p /etc/iptables

    if sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null; then
        print_success "Rules saved to /etc/iptables/rules.v4"
    else
        print_error "Failed to save rules"
    fi
else
    print_info "Rules not saved (will be lost on reboot)"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Recovery Summary"
echo "==============================="
echo ""

print_success "Connectivity restoration complete!"
echo ""
print_info "Current status:"
echo "  • All iptables policies: ACCEPT"
echo "  • INPUT/FORWARD/OUTPUT chains: Flushed"
echo "  • NAT (MASQUERADE): Preserved"
echo "  • FORWARD rules: Re-added (bat0 ↔ wlan1)"
echo ""

INTERNET_OK=$(ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo "YES" || echo "NO")
WLAN1_OK=$(ip addr show wlan1 2>/dev/null | grep -q "inet " && echo "YES" || echo "NO")

if [ "$INTERNET_OK" = "YES" ] && [ "$WLAN1_OK" = "YES" ]; then
    print_success "Internet and SSH should be restored!"
    echo ""
    print_info "Next steps:"
    echo "  1. Test SSH connection from another device"
    echo "  2. Re-run Phase 5 if you want stricter rules"
    echo "  3. The updated Phase 5 script has better protections"
else
    print_warning "Connectivity may not be fully restored"
    echo ""
    print_info "Manual troubleshooting:"
    echo "  • Check wlan1: sudo systemctl status wlan1-internet"
    echo "  • Restart wlan1: sudo systemctl restart wlan1-internet"
    echo "  • Check IP: ip addr show wlan1"
    echo "  • Test ping: ping -c 3 8.8.8.8"
    echo "  • View iptables: sudo iptables -L -v -n"
fi

echo ""
exit 0

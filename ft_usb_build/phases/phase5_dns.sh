#!/bin/bash

################################################################################
# Phase 4: DNS/DHCP (dnsmasq)
# Configures dnsmasq to provide DHCP and DNS services to mesh devices
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

# USB logging - capture all output to log file
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase5_dns_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
ln -sf "$LOG_FILE" "${LOG_DIR}/phase5_dns_latest.log"
echo "========================================" && echo "Field Trainer Installation - Phase 5: DNS/DHCP" && echo "Date: $(date)" && echo "Hostname: $(hostname)" && echo "Log: $LOG_FILE" && echo "========================================"
echo ""

# DHCP configuration
DHCP_RANGE_START="192.168.99.101"
DHCP_RANGE_END="192.168.99.200"
DHCP_LEASE_TIME="12h"

echo "Phase 4: DNS/DHCP (dnsmasq)"
echo "==========================="
echo ""
echo "This phase configures dnsmasq to provide:"
echo "  • DHCP service for mesh clients (Devices 1-5)"
echo "  • DNS forwarding for internet access"
echo ""
echo "Default DHCP configuration:"
echo "  • Interface: bat0 (mesh network)"
echo "  • IP Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
echo "  • Gateway: 192.168.99.100 (Device 0)"
echo "  • DNS: 8.8.8.8, 8.8.4.4 (Google DNS)"
echo "  • Lease Time: $DHCP_LEASE_TIME"
echo ""
read -p "Press Enter to begin configuration..."
echo ""

################################################################################
# Step 1: Verify Prerequisites
################################################################################

echo "Step 1: Verifying Prerequisites..."
echo "-----------------------------------"

# Check dnsmasq installed
echo -n "  dnsmasq... "
if command -v dnsmasq &>/dev/null; then
    print_success "installed"
else
    print_error "not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check bat0 exists
echo -n "  bat0 interface... "
if ip link show bat0 &>/dev/null; then
    print_success "exists"
    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo "    bat0 IP: $BAT0_IP"
else
    print_error "not found"
    print_warning "Please complete Phase 3 first"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Prerequisites not met"
    exit 1
fi

################################################################################
# Step 2: Stop and Disable Conflicting Services
################################################################################

echo "Step 2: Checking for Conflicting Services..."
echo "---------------------------------------------"

# Check if dnsmasq is already running
if systemctl is-active --quiet dnsmasq; then
    print_warning "dnsmasq is currently running"
    print_info "Stopping dnsmasq for configuration..."
    sudo systemctl stop dnsmasq
fi

# Check for systemd-resolved conflicts
if systemctl is-active --quiet systemd-resolved; then
    print_warning "systemd-resolved is running (may conflict with dnsmasq)"
    read -p "Disable systemd-resolved? (recommended, y/n): " disable_resolved
    if [[ $disable_resolved =~ ^[Yy]$ ]]; then
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved
        print_success "systemd-resolved disabled"
    fi
fi

echo ""

################################################################################
# Step 3: Backup Existing Configuration
################################################################################

echo "Step 3: Backing Up Existing Configuration..."
echo "---------------------------------------------"

DNSMASQ_CONF="/etc/dnsmasq.conf"
BACKUP_CONF="${DNSMASQ_CONF}.backup.$(date +%Y%m%d_%H%M%S)"

if [ -f "$DNSMASQ_CONF" ]; then
    print_info "Creating backup: $BACKUP_CONF"
    sudo cp "$DNSMASQ_CONF" "$BACKUP_CONF"
    print_success "Backup created"
else
    print_info "No existing configuration found"
fi

echo ""

################################################################################
# Step 4: Create dnsmasq Configuration
################################################################################

echo "Step 4: Creating dnsmasq Configuration..."
echo "------------------------------------------"

print_info "Creating $DNSMASQ_CONF"

sudo tee "$DNSMASQ_CONF" > /dev/null << EOF
################################################################################
# Field Trainer - dnsmasq Configuration
# Device 0 (Gateway)
################################################################################

# Listen only on bat0 (mesh network)
interface=bat0

# Don't read /etc/resolv.conf or /etc/hosts
no-resolv
no-hosts

# Use Google DNS for upstream
server=8.8.8.8
server=8.8.4.4

# DHCP Configuration
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$DHCP_LEASE_TIME

# Gateway (this device)
dhcp-option=option:router,$BAT0_IP

# DNS servers for clients
dhcp-option=option:dns-server,$BAT0_IP

# Domain name
domain=fieldtrainer.local

# Enable DHCP logging
log-dhcp

# Log to syslog
log-facility=/var/log/dnsmasq.log

# Don't forward plain names (without a dot)
domain-needed

# Don't forward addresses in non-routed address spaces
bogus-priv

# Cache size
cache-size=1000


# Static DHCP assignments for devices (optional)
# Uncomment and adjust MAC addresses as needed:
# dhcp-host=XX:XX:XX:XX:XX:01,192.168.99.101,device1,infinite
# dhcp-host=XX:XX:XX:XX:XX:02,192.168.99.102,device2,infinite
# dhcp-host=XX:XX:XX:XX:XX:03,192.168.99.103,device3,infinite
# dhcp-host=XX:XX:XX:XX:XX:04,192.168.99.104,device4,infinite
# dhcp-host=XX:XX:XX:XX:XX:05,192.168.99.105,device5,infinite

EOF

if [ $? -eq 0 ]; then
    print_success "Configuration file created"
else
    print_error "Failed to create configuration file"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 5: Create Log File
################################################################################

echo "Step 5: Creating Log File..."
echo "----------------------------"

print_info "Creating /var/log/dnsmasq.log"

sudo touch /var/log/dnsmasq.log
sudo chmod 644 /var/log/dnsmasq.log

if [ -f /var/log/dnsmasq.log ]; then
    print_success "Log file created"
else
    print_error "Failed to create log file"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 6: Test Configuration
################################################################################

echo "Step 6: Testing Configuration..."
echo "--------------------------------"

print_info "Checking dnsmasq configuration syntax..."

if sudo dnsmasq --test; then
    print_success "Configuration syntax is valid"
else
    print_error "Configuration has syntax errors"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Configuration test failed"
    exit 1
fi

################################################################################
# Step 7: Enable and Start Service
################################################################################

echo "Step 7: Starting dnsmasq Service..."
echo "------------------------------------"

print_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

print_info "Enabling dnsmasq.service..."
if sudo systemctl enable dnsmasq; then
    print_success "Service enabled (will start on boot)"
else
    print_error "Failed to enable service"
    ERRORS=$((ERRORS + 1))
fi

print_info "Starting dnsmasq.service..."
if sudo systemctl start dnsmasq; then
    print_success "Service started"
else
    print_error "Failed to start service"
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 8: Verify Service Status
################################################################################

echo "Step 8: Verifying Service..."
echo "----------------------------"

sleep 2

if systemctl is-active --quiet dnsmasq; then
    print_success "dnsmasq is running"
    
    # Show listening ports
    print_info "Listening on:"
    sudo netstat -tulpn 2>/dev/null | grep dnsmasq | head -n 5
    
else
    print_error "dnsmasq is not running"
    print_warning "Checking logs for errors..."
    sudo journalctl -u dnsmasq -n 20 --no-pager
    ERRORS=$((ERRORS + 1))
fi

echo ""

################################################################################
# Step 9: Test DHCP Server
################################################################################

echo "Step 9: Testing DHCP Server..."
echo "-------------------------------"

print_info "Checking DHCP leases file..."

LEASES_FILE="/var/lib/misc/dnsmasq.leases"
if [ -f "$LEASES_FILE" ]; then
    print_success "Leases file exists: $LEASES_FILE"
    
    LEASE_COUNT=$(wc -l < "$LEASES_FILE")
    echo "  Current leases: $LEASE_COUNT"
    
    if [ $LEASE_COUNT -gt 0 ]; then
        print_info "Active leases:"
        cat "$LEASES_FILE"
    fi
else
    print_info "No leases file yet (will be created when first client connects)"
fi

echo ""

################################################################################
# Step 10: Test DNS Resolution
################################################################################

echo "Step 10: Testing DNS Resolution..."
echo "-----------------------------------"

print_info "Testing DNS query through dnsmasq..."

# Test DNS resolution
if nslookup google.com $BAT0_IP &>/dev/null; then
    print_success "DNS resolution working"
else
    print_warning "DNS resolution test failed"
    print_info "This may be normal if internet not configured yet"
fi

echo ""

################################################################################
# Summary
################################################################################

echo "==============================="
echo "Configuration Summary"
echo "==============================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "DNS/DHCP configured successfully!"
    echo ""
    print_info "Configuration:"
    echo "  • Config file: $DNSMASQ_CONF"
    echo "  • Backup: $BACKUP_CONF"
    echo "  • Log file: /var/log/dnsmasq.log"
    echo "  • Leases: $LEASES_FILE"
    echo ""
    print_info "DHCP settings:"
    echo "  • Interface: bat0"
    echo "  • Range: $DHCP_RANGE_START - $DHCP_RANGE_END"
    echo "  • Gateway: $BAT0_IP"
    echo "  • DNS: $BAT0_IP (forwarding to 8.8.8.8, 8.8.4.4)"
    echo "  • Lease time: $DHCP_LEASE_TIME"
    echo ""
    print_info "Service status:"
    echo "  • dnsmasq is running and enabled"
    echo "  • Ready to serve DHCP clients"
    echo ""
    print_warning "Note: Client devices will receive IPs when they connect to mesh"
    echo ""
    print_info "Ready to proceed to Phase 5 (NAT/Firewall)"
    echo ""
    exit 0
else
    print_error "Found $ERRORS error(s) during configuration"
    echo ""
    print_warning "Please resolve issues before continuing"
    echo ""
    exit 1
fi
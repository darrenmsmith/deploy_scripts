#!/bin/bash

################################################################################
# Fix Phase 5 dnsmasq Configuration
# Removes invalid IP addresses from dnsmasq.conf
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Fix Phase 5 - dnsmasq Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""

DNSMASQ_CONF="/etc/dnsmasq.conf"

# Check if config exists
if [ ! -f "$DNSMASQ_CONF" ]; then
    echo -e "${RED}✗ $DNSMASQ_CONF not found${NC}"
    exit 1
fi

echo -e "${BLUE}[1/5] Backing up current configuration...${NC}"
sudo cp "$DNSMASQ_CONF" "${DNSMASQ_CONF}.broken.backup"
echo -e "${GREEN}✓ Backup created: ${DNSMASQ_CONF}.broken.backup${NC}"
echo ""

echo -e "${BLUE}[2/5] Getting bat0 primary IP...${NC}"
# Get only the primary IP (exclude link-local 169.254.x.x)
BAT0_IP=$(ip addr show bat0 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d/ -f1 | head -1)

if [ -z "$BAT0_IP" ]; then
    echo -e "${RED}✗ Could not get bat0 IP address${NC}"
    exit 1
fi

echo -e "${GREEN}✓ bat0 IP: $BAT0_IP${NC}"
echo ""

echo -e "${BLUE}[3/5] Creating corrected dnsmasq configuration...${NC}"

sudo tee "$DNSMASQ_CONF" > /dev/null << EOF
################################################################################
# Field Trainer - dnsmasq Configuration
# Device 0 (Gateway)
# FIXED: Removed invalid standalone IP addresses
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
dhcp-range=192.168.99.101,192.168.99.200,12h

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

# Don't forward requests for plain names
domain-needed

# Don't forward reverse lookups for private IP ranges
bogus-priv

# Cache size
cache-size=1000
EOF

echo -e "${GREEN}✓ Configuration file updated${NC}"
echo ""

echo -e "${BLUE}[4/5] Testing configuration syntax...${NC}"
if sudo dnsmasq --test; then
    echo -e "${GREEN}✓ Configuration syntax is valid${NC}"
else
    echo -e "${RED}✗ Configuration still has errors${NC}"
    exit 1
fi
echo ""

echo -e "${BLUE}[5/5] Starting dnsmasq service...${NC}"
sudo systemctl daemon-reload
sudo systemctl restart dnsmasq

sleep 3

if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}✓ dnsmasq service is RUNNING${NC}"
else
    echo -e "${RED}✗ dnsmasq service failed to start${NC}"
    echo ""
    echo "Service status:"
    sudo systemctl status dnsmasq --no-pager -l
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓✓✓ Phase 5 Fixed Successfully! ✓✓✓${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "dnsmasq is now providing:"
echo "  • DHCP: 192.168.99.101 - 192.168.99.200"
echo "  • DNS: Forwarding to 8.8.8.8 and 8.8.4.4"
echo "  • Gateway: $BAT0_IP"
echo ""
echo "You can now continue with Phase 6 (NAT/Firewall)"
echo ""
echo "════════════════════════════════════════════════════════════"

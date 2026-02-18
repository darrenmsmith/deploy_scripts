#!/bin/bash

################################################################################
# Check Phase 5 (DNS/DHCP) Failure
# Captures diagnostic info for dnsmasq setup issues
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/tmp/phase5_error_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Phase 5 (DNS/DHCP) Diagnostics"
echo "  Timestamp: $(date)"
echo "  Log file: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}[1/8] Check if dnsmasq is installed${NC}"
echo "──────────────────────────────────────"
if command -v dnsmasq &>/dev/null; then
    echo -e "${GREEN}✓ dnsmasq is installed${NC}"
    dnsmasq --version | head -1
else
    echo -e "${RED}✗ dnsmasq is NOT installed${NC}"
fi
echo ""

echo -e "${BLUE}[2/8] Check dnsmasq service status${NC}"
echo "──────────────────────────────────────"
sudo systemctl status dnsmasq --no-pager -l
echo ""

echo -e "${BLUE}[3/8] Check dnsmasq configuration${NC}"
echo "──────────────────────────────────────"
if [ -f /etc/dnsmasq.conf ]; then
    echo "dnsmasq.conf exists"
    echo ""
    echo "Active configuration (non-comment lines):"
    grep -v "^#\|^$" /etc/dnsmasq.conf
else
    echo -e "${RED}✗ /etc/dnsmasq.conf not found${NC}"
fi
echo ""

echo -e "${BLUE}[4/8] Check dnsmasq logs${NC}"
echo "──────────────────────────────────────"
sudo journalctl -u dnsmasq -n 30 --no-pager
echo ""

echo -e "${BLUE}[5/8] Check bat0 interface${NC}"
echo "──────────────────────────────────────"
ip addr show bat0
echo ""

echo -e "${BLUE}[6/8] Check if dnsmasq config directory exists${NC}"
echo "──────────────────────────────────────"
if [ -d /etc/dnsmasq.d ]; then
    echo -e "${GREEN}✓ /etc/dnsmasq.d exists${NC}"
    echo "Contents:"
    ls -la /etc/dnsmasq.d/
else
    echo -e "${RED}✗ /etc/dnsmasq.d directory not found${NC}"
fi
echo ""

echo -e "${BLUE}[7/8] Test dnsmasq configuration syntax${NC}"
echo "──────────────────────────────────────"
if [ -f /etc/dnsmasq.conf ]; then
    sudo dnsmasq --test
else
    echo "Cannot test - config file missing"
fi
echo ""

echo -e "${BLUE}[8/8] Check for port conflicts${NC}"
echo "──────────────────────────────────────"
echo "Processes using port 53 (DNS):"
sudo lsof -i :53 2>/dev/null || echo "  None found"
echo ""
echo "Processes using port 67 (DHCP):"
sudo lsof -i :67 2>/dev/null || echo "  None found"
echo ""

echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $LOG_FILE"

if [ -d /mnt/usb/ft_usb_build ]; then
    USB_LOG="/mnt/usb/ft_usb_build/phase5_error_$(date +%Y%m%d_%H%M%S).log"
    cp "$LOG_FILE" "$USB_LOG"
    echo "Log copied to USB: $USB_LOG"
fi

echo ""
echo "════════════════════════════════════════════════════════════"

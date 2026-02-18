#!/bin/bash

################################################################################
# Phase 2 Diagnostic Tool
# Run this on build system to diagnose Phase 2 issues
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup logging
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/phase2_diagnostic_${TIMESTAMP}.log"

# Function to output to both console and log
log_output() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE}========================================"
echo "Phase 2 Diagnostic Tool"
echo "Log: $LOG_FILE"
echo -e "========================================${NC}"
echo ""

echo -e "${YELLOW}1. System Information${NC}"
echo "-------------------"
echo "Date/Time: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo ""

echo -e "${YELLOW}2. Network Interfaces${NC}"
echo "-------------------"
ip link show | grep -E "^[0-9]:" | awk '{print $2}'
echo ""

echo -e "${YELLOW}3. wlan1 Status${NC}"
echo "-------------------"
if ip link show wlan1 &>/dev/null; then
    echo -e "${GREEN}✓ wlan1 exists${NC}"
    ip addr show wlan1
    echo ""
    echo "WiFi Connection Quality:"
    if which iw &>/dev/null; then
        sudo iw dev wlan1 link 2>/dev/null || echo "  Not connected or iw failed"
    else
        echo "  iw not installed"
    fi
    echo ""
    echo "WiFi Signal:"
    if which iwconfig &>/dev/null; then
        iwconfig wlan1 2>&1 | grep -E "Signal level|Link Quality" || echo "  No signal info"
    else
        echo "  iwconfig not installed"
    fi
else
    echo -e "${RED}✗ wlan1 not found${NC}"
fi
echo ""

echo -e "${YELLOW}4. dhcpcd Installation${NC}"
echo "-------------------"
if which dhcpcd &>/dev/null; then
    echo -e "${GREEN}✓ dhcpcd installed${NC}"
    dhcpcd --version | head -1
else
    echo -e "${RED}✗ dhcpcd NOT installed${NC}"
fi
echo ""

echo -e "${YELLOW}5. wpa_supplicant Installation${NC}"
echo "-------------------"
if which wpa_supplicant &>/dev/null; then
    echo -e "${GREEN}✓ wpa_supplicant installed${NC}"
    wpa_supplicant -v | head -1
else
    echo -e "${RED}✗ wpa_supplicant NOT installed${NC}"
fi
echo ""

echo -e "${YELLOW}6. WiFi Configuration${NC}"
echo "-------------------"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
if [ -f "$WPA_CONF" ]; then
    echo -e "${GREEN}✓ Config exists: $WPA_CONF${NC}"
    echo "Contents:"
    sudo cat "$WPA_CONF" | sed 's/psk=.*/psk=***HIDDEN***/'
    echo ""
    if grep -q "ctrl_interface" "$WPA_CONF"; then
        echo -e "${GREEN}✓ Has ctrl_interface${NC}"
    else
        echo -e "${RED}✗ Missing ctrl_interface${NC}"
    fi
    if grep -q "network=" "$WPA_CONF"; then
        echo -e "${GREEN}✓ Has network block${NC}"
    else
        echo -e "${RED}✗ Missing network block${NC}"
    fi
else
    echo -e "${RED}✗ Config not found: $WPA_CONF${NC}"
fi
echo ""

echo -e "${YELLOW}7. Running Processes${NC}"
echo "-------------------"
echo "wpa_supplicant:"
ps aux | grep "[w]pa_supplicant.*wlan1" || echo "  Not running"
echo ""
echo "dhcpcd:"
ps aux | grep "[d]hcpcd.*wlan1" || echo "  Not running"
echo ""

echo -e "${YELLOW}8. Systemd Services${NC}"
echo "-------------------"
for service in wlan1-wpa wlan1-dhcp wlan1-internet; do
    if systemctl list-unit-files | grep -q "^${service}.service"; then
        echo -e "${BLUE}Service: ${service}.service${NC}"
        systemctl status ${service}.service --no-pager 2>&1 | head -10
        echo ""
    fi
done

echo -e "${YELLOW}9. PID Files${NC}"
echo "-------------------"
echo "/run/wpa_supplicant-wlan1.pid:"
if [ -f /run/wpa_supplicant-wlan1.pid ]; then
    echo -e "${GREEN}✓ Exists${NC}"
    echo "  PID: $(cat /run/wpa_supplicant-wlan1.pid)"
else
    echo -e "${RED}✗ Not found${NC}"
fi
echo ""

echo "/run/dhcpcd/wlan1.pid:"
if [ -f /run/dhcpcd/wlan1.pid ]; then
    echo -e "${GREEN}✓ Exists${NC}"
    echo "  PID: $(cat /run/dhcpcd/wlan1.pid)"
else
    echo -e "${RED}✗ Not found${NC}"
fi
echo ""

echo -e "${YELLOW}10. Recent Logs${NC}"
echo "-------------------"
echo "Phase 2 logs:"
ls -lht /mnt/usb/install_logs/phase2_internet_*.log 2>/dev/null | head -3 || echo "  No logs found"
echo ""

echo -e "${YELLOW}11. systemd Journal (last 50 lines)${NC}"
echo "-------------------"
sudo journalctl -u wlan1-wpa.service -u wlan1-dhcp.service --no-pager -n 50 2>&1 | tail -20

echo ""
echo -e "${YELLOW}12. Network Connectivity Test${NC}"
echo "-------------------"
echo "Gateway ping test:"
GATEWAY=$(ip route | grep "default.*wlan1" | awk '{print $3}')
if [ -n "$GATEWAY" ]; then
    echo "  Gateway: $GATEWAY"
    if ping -c 3 -W 2 "$GATEWAY" &>/dev/null; then
        echo -e "  ${GREEN}✓ Gateway reachable${NC}"
    else
        echo -e "  ${RED}✗ Gateway unreachable${NC}"
    fi
else
    echo -e "  ${RED}✗ No default gateway${NC}"
fi
echo ""

echo "Internet ping test:"
if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "  ${GREEN}✓ Internet reachable (8.8.8.8)${NC}"
else
    echo -e "  ${RED}✗ Internet unreachable${NC}"
fi
echo ""

echo "DNS test:"
if host google.com &>/dev/null; then
    echo -e "  ${GREEN}✓ DNS working${NC}"
else
    echo -e "  ${RED}✗ DNS not working${NC}"
fi

echo ""
echo -e "${BLUE}========================================"
echo "Diagnostic Complete"
echo "Log saved to: $LOG_FILE"
echo -e "========================================${NC}"

# Create symlink to latest
ln -sf "$LOG_FILE" "${LOG_DIR}/phase2_diagnostic_latest.log"

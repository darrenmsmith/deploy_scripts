#!/bin/bash

################################################################################
# Post-Installation Verification Script
# Run after reboot to verify Field Trainer installation
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================"
echo "Field Trainer Installation Verification"
echo -e "========================================${NC}"
echo ""

# Setup logging
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/post_install_verify_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "Log: $LOG_FILE"
echo ""

ERRORS=0
WARNINGS=0

################################################################################
# 1. System Info
################################################################################

echo -e "${BLUE}1. System Information${NC}"
echo "-------------------"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo ""

################################################################################
# 2. Network Services
################################################################################

echo -e "${BLUE}2. Network Services${NC}"
echo "-------------------"

# wlan1-wpa.service
if systemctl is-active --quiet wlan1-wpa.service; then
    echo -e "${GREEN}✓ wlan1-wpa.service: active${NC}"
    systemctl status wlan1-wpa.service --no-pager | grep -E "Active:|Main PID:" | head -2
else
    echo -e "${RED}✗ wlan1-wpa.service: NOT active${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# wlan1-dhcp.service
if systemctl is-active --quiet wlan1-dhcp.service; then
    echo -e "${GREEN}✓ wlan1-dhcp.service: active${NC}"
    systemctl status wlan1-dhcp.service --no-pager | grep -E "Active:|Main PID:" | head -2
else
    echo -e "${RED}✗ wlan1-dhcp.service: NOT active${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

################################################################################
# 3. Network Connectivity
################################################################################

echo -e "${BLUE}3. Network Connectivity${NC}"
echo "-------------------"

# wlan1 IP address
WLAN1_IP=$(ip addr show wlan1 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)
if [ -n "$WLAN1_IP" ]; then
    echo -e "${GREEN}✓ wlan1 IP: $WLAN1_IP${NC}"
else
    IPV4LL=$(ip addr show wlan1 2>/dev/null | grep "inet 169.254" | awk '{print $2}')
    if [ -n "$IPV4LL" ]; then
        echo -e "${YELLOW}⚠ wlan1 has IPv4LL: $IPV4LL (no DHCP)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${RED}✗ wlan1: No IP address${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# WiFi connection
if which iw &>/dev/null; then
    echo "WiFi Details:"
    sudo iw dev wlan1 link 2>/dev/null | grep -E "SSID|signal" || echo "  Not connected"
    echo ""
fi

# Gateway
GATEWAY=$(ip route | grep "default.*wlan1" | awk '{print $3}')
if [ -n "$GATEWAY" ]; then
    echo -e "Gateway: $GATEWAY"
    if ping -c 3 -W 2 "$GATEWAY" &>/dev/null; then
        echo -e "${GREEN}✓ Gateway reachable${NC}"
    else
        echo -e "${RED}✗ Gateway unreachable${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ No default gateway${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Internet
if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓ Internet reachable (8.8.8.8)${NC}"
else
    echo -e "${RED}✗ Internet unreachable${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# DNS
if host google.com &>/dev/null; then
    echo -e "${GREEN}✓ DNS working${NC}"
else
    echo -e "${YELLOW}⚠ DNS not working (may not affect operation)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

################################################################################
# 4. Field Trainer Application
################################################################################

echo -e "${BLUE}4. Field Trainer Application${NC}"
echo "-------------------"

# Check for FT service (try multiple possible names)
FT_SERVICE=""
for svc in field-trainer field_trainer fieldtrainer ft; do
    if systemctl list-unit-files | grep -q "^${svc}.service"; then
        FT_SERVICE="${svc}.service"
        break
    fi
done

if [ -n "$FT_SERVICE" ]; then
    echo "Found service: $FT_SERVICE"
    if systemctl is-active --quiet "$FT_SERVICE"; then
        echo -e "${GREEN}✓ $FT_SERVICE: active${NC}"
        systemctl status "$FT_SERVICE" --no-pager | grep -E "Active:|Main PID:" | head -2
    else
        echo -e "${YELLOW}⚠ $FT_SERVICE: NOT active${NC}"
        echo "Status:"
        systemctl status "$FT_SERVICE" --no-pager | head -10
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Field Trainer service not found${NC}"
    echo "Checking for common service names..."
    systemctl list-unit-files | grep -i "field\|trainer" || echo "  None found"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check for FT directory
FT_DIRS=("/opt/field_trainer" "/home/pi/field_trainer" "/usr/local/field_trainer")
FT_DIR=""
for dir in "${FT_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        FT_DIR="$dir"
        break
    fi
done

if [ -n "$FT_DIR" ]; then
    echo -e "${GREEN}✓ Field Trainer directory: $FT_DIR${NC}"
    echo "Contents:"
    ls -lh "$FT_DIR" | head -10
else
    echo -e "${YELLOW}⚠ Field Trainer directory not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

################################################################################
# 5. Database
################################################################################

echo -e "${BLUE}5. Database${NC}"
echo "-------------------"

if [ -n "$FT_DIR" ]; then
    DB_FILE=$(find "$FT_DIR" -name "*.db" 2>/dev/null | head -1)
    if [ -n "$DB_FILE" ]; then
        echo -e "${GREEN}✓ Database found: $DB_FILE${NC}"
        echo "Size: $(du -h "$DB_FILE" | cut -f1)"
    else
        echo -e "${YELLOW}⚠ No database file found${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "Cannot check - FT directory unknown"
fi
echo ""

################################################################################
# 6. Web Interface
################################################################################

echo -e "${BLUE}6. Web Interface${NC}"
echo "-------------------"

# Check if Flask is running
if pgrep -f "flask.*run\|python.*app\.py\|gunicorn" >/dev/null; then
    echo -e "${GREEN}✓ Flask/Python web app running${NC}"
    echo "Processes:"
    ps aux | grep -E "flask|gunicorn|python.*app" | grep -v grep | head -5
else
    echo -e "${YELLOW}⚠ No Flask/Python web app detected${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Try to access web interface
if [ -n "$WLAN1_IP" ]; then
    for port in 5000 80 8080; do
        if nc -z -w 2 "$WLAN1_IP" $port 2>/dev/null; then
            echo -e "${GREEN}✓ Web interface listening on port $port${NC}"
            echo "  Access at: http://${WLAN1_IP}:${port}"
            break
        fi
    done
fi
echo ""

################################################################################
# 7. Process Check
################################################################################

echo -e "${BLUE}7. Running Processes${NC}"
echo "-------------------"

echo "wpa_supplicant:"
ps aux | grep "[w]pa_supplicant.*wlan1" || echo "  Not running"
echo ""

echo "dhcpcd:"
ps aux | grep "[d]hcpcd.*wlan1" || echo "  Not running"
echo ""

################################################################################
# 8. Installation Logs Review
################################################################################

echo -e "${BLUE}8. Installation Logs${NC}"
echo "-------------------"

if [ -d "$LOG_DIR" ]; then
    echo "Recent installation logs:"
    ls -lht "$LOG_DIR"/*.log 2>/dev/null | head -10 || echo "  No logs found"
    echo ""

    # Check for errors in Phase 3
    if [ -f "$LOG_DIR/phase3_packages_latest.log" ]; then
        echo "Phase 3 errors/warnings:"
        grep -i "error\|fail\|warn" "$LOG_DIR/phase3_packages_latest.log" | tail -5 || echo "  None found"
    fi
else
    echo "Log directory not found"
fi
echo ""

################################################################################
# Summary
################################################################################

echo ""
echo -e "${BLUE}========================================"
echo "Verification Summary"
echo -e "========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "Installation appears successful!"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH $WARNINGS WARNING(S)${NC}"
    echo ""
    echo "Installation mostly successful, but check warnings above."
else
    echo -e "${RED}✗ FAILED: $ERRORS ERROR(S), $WARNINGS WARNING(S)${NC}"
    echo ""
    echo "Installation has issues that need attention."
fi

echo ""
echo "Log saved to: $LOG_FILE"
echo ""

exit $ERRORS

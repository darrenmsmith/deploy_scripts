#!/bin/bash

################################################################################
# Check Field Trainer Application Status
# Why is port 5001 (Coach interface) not accessible?
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/tmp/field_trainer_check_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Field Trainer Application Diagnostics"
echo "  Timestamp: $(date)"
echo "  Log file: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}[1/10] Check field-trainer service status${NC}"
echo "──────────────────────────────────────"
sudo systemctl status field-trainer --no-pager -l
echo ""

echo -e "${BLUE}[2/10] Check what ports are listening${NC}"
echo "──────────────────────────────────────"
echo "Port 5000 (Admin):"
sudo lsof -i :5000 2>/dev/null || echo "  Nothing listening on 5000"
echo ""
echo "Port 5001 (Coach):"
sudo lsof -i :5001 2>/dev/null || echo "  Nothing listening on 5001"
echo ""
echo "Port 6000 (Client server):"
sudo lsof -i :6000 2>/dev/null || echo "  Nothing listening on 6000"
echo ""

echo -e "${BLUE}[3/10] Check all Python processes${NC}"
echo "──────────────────────────────────────"
ps aux | grep -E "python|field" | grep -v grep
echo ""

echo -e "${BLUE}[4/10] Check field-trainer application location${NC}"
echo "──────────────────────────────────────"
if [ -d /opt/field-trainer ]; then
    echo -e "${GREEN}✓ /opt/field-trainer exists${NC}"
    ls -la /opt/field-trainer/ | head -20
else
    echo -e "${RED}✗ /opt/field-trainer NOT FOUND${NC}"
fi
echo ""

echo -e "${BLUE}[5/10] Check main application file${NC}"
echo "──────────────────────────────────────"
if [ -f /opt/field-trainer/main.py ]; then
    echo -e "${GREEN}✓ main.py exists${NC}"
    ls -la /opt/field-trainer/main.py
    echo ""
    echo "First 30 lines:"
    head -30 /opt/field-trainer/main.py
else
    echo -e "${RED}✗ main.py NOT FOUND${NC}"
fi
echo ""

echo -e "${BLUE}[6/10] Check recent application logs${NC}"
echo "──────────────────────────────────────"
sudo journalctl -u field-trainer -n 50 --no-pager
echo ""

echo -e "${BLUE}[7/10] Check if ports are bound to specific IP${NC}"
echo "──────────────────────────────────────"
sudo netstat -tulpn | grep -E ":5000|:5001|:6000"
echo ""

echo -e "${BLUE}[8/10] Check firewall rules${NC}"
echo "──────────────────────────────────────"
echo "iptables INPUT rules:"
sudo iptables -L INPUT -n -v | head -20
echo ""
echo "iptables FORWARD rules:"
sudo iptables -L FORWARD -n -v | head -20
echo ""

echo -e "${BLUE}[9/10] Test local connectivity${NC}"
echo "──────────────────────────────────────"
echo "Testing localhost:5000..."
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5000 2>/dev/null || echo "  Cannot connect"
echo ""
echo "Testing localhost:5001..."
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:5001 2>/dev/null || echo "  Cannot connect"
echo ""
echo "Testing 192.168.99.100:5000..."
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.99.100:5000 2>/dev/null || echo "  Cannot connect"
echo ""
echo "Testing 192.168.99.100:5001..."
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://192.168.99.100:5001 2>/dev/null || echo "  Cannot connect"
echo ""

echo -e "${BLUE}[10/10] Check systemd service file${NC}"
echo "──────────────────────────────────────"
if [ -f /etc/systemd/system/field-trainer.service ]; then
    echo "Service file contents:"
    cat /etc/systemd/system/field-trainer.service
else
    echo -e "${RED}✗ Service file NOT FOUND${NC}"
fi
echo ""

echo "════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo ""

# Quick summary
if systemctl is-active --quiet field-trainer; then
    echo -e "${GREEN}✓ field-trainer service is RUNNING${NC}"
else
    echo -e "${RED}✗ field-trainer service is NOT RUNNING${NC}"
fi

if sudo lsof -i :5000 &>/dev/null; then
    echo -e "${GREEN}✓ Port 5000 is listening (Admin working)${NC}"
else
    echo -e "${RED}✗ Port 5000 is NOT listening${NC}"
fi

if sudo lsof -i :5001 &>/dev/null; then
    echo -e "${GREEN}✓ Port 5001 is listening (Coach working)${NC}"
else
    echo -e "${RED}✗ Port 5001 is NOT listening (Coach NOT working)${NC}"
fi

echo ""
echo "Log saved to: $LOG_FILE"

if [ -d /mnt/usb/ft_usb_build ]; then
    USB_LOG="/mnt/usb/ft_usb_build/field_trainer_check_$(date +%Y%m%d_%H%M%S).log"
    cp "$LOG_FILE" "$USB_LOG"
    echo "Log copied to USB: $USB_LOG"
fi

echo ""
echo "════════════════════════════════════════════════════════════"

#!/bin/bash
# Fix Coach Interface Port 5001 - Restart Field Trainer Service
# Issue: Service has old code loaded in memory, needs restart to pick up current coach_interface.py
# Date: 2026-01-04

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Fix Coach Interface Port 5001${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check current service status
echo -e "${YELLOW}[1] Checking current Field Trainer service status...${NC}"
sudo systemctl status field-trainer-server --no-pager | head -10
echo ""

# Check current ports
echo -e "${YELLOW}[2] Checking current port status...${NC}"
echo "Ports before restart:"
sudo netstat -tulpn | grep ":500" || echo "No ports 5000/5001 listening"
echo ""

# Check process start time vs file modification time
echo -e "${YELLOW}[3] Checking for stale code in memory...${NC}"
PID=$(pgrep -f "field_trainer_main.py" | head -1)
if [ -n "$PID" ]; then
    echo "Process PID: $PID"
    echo "Process started:"
    ps -p $PID -o lstart --no-headers
    echo ""
    echo "coach_interface.py last modified:"
    stat /opt/coach_interface.py | grep "Modify:"
    echo ""
else
    echo -e "${RED}✗ Field Trainer process not running${NC}"
fi

# Restart the service
echo -e "${YELLOW}[4] Restarting Field Trainer service...${NC}"
sudo systemctl restart field-trainer-server
echo -e "${GREEN}✓ Restart command sent${NC}"
echo ""

# Wait for service to start
echo "Waiting 5 seconds for service to start..."
sleep 5
echo ""

# Check new service status
echo -e "${YELLOW}[5] Checking new service status...${NC}"
sudo systemctl status field-trainer-server --no-pager | head -15
echo ""

# Check new ports
echo -e "${YELLOW}[6] Checking new port status...${NC}"
echo "Ports after restart:"
sudo netstat -tulpn | grep ":500"
echo ""

# Test both interfaces
echo -e "${YELLOW}[7] Testing interfaces...${NC}"
echo -n "Port 5000 (Admin): "
HTTP_CODE_5000=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 2>/dev/null)
if [ "$HTTP_CODE_5000" = "200" ] || [ "$HTTP_CODE_5000" = "302" ]; then
    echo -e "${GREEN}✓ HTTP $HTTP_CODE_5000${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_CODE_5000${NC}"
fi

echo -n "Port 5001 (Coach): "
HTTP_CODE_5001=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001 2>/dev/null)
if [ "$HTTP_CODE_5001" = "200" ] || [ "$HTTP_CODE_5001" = "302" ]; then
    echo -e "${GREEN}✓ HTTP $HTTP_CODE_5001${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_CODE_5001${NC}"
fi
echo ""

# Check recent logs for errors
echo -e "${YELLOW}[8] Checking for startup errors...${NC}"
sudo journalctl -u field-trainer-server --since "1 minute ago" | grep -i "error\|failed\|exception" | tail -10
if [ $? -ne 0 ]; then
    echo -e "${GREEN}✓ No errors found in recent logs${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
if [ "$HTTP_CODE_5000" = "200" ] || [ "$HTTP_CODE_5000" = "302" ]; then
    if [ "$HTTP_CODE_5001" = "200" ] || [ "$HTTP_CODE_5001" = "302" ]; then
        echo -e "${GREEN}✓ SUCCESS! Both interfaces are now working:${NC}"
        echo ""
        echo "  Admin Interface:  http://$(hostname -I | awk '{print $1}'):5000"
        echo "  Coach Interface:  http://$(hostname -I | awk '{print $1}'):5001"
        echo ""
        echo -e "${GREEN}You can now access the Coach interface from your browser!${NC}"
    else
        echo -e "${RED}✗ Port 5001 (Coach) is still not responding${NC}"
        echo "Check the logs above for errors"
    fi
else
    echo -e "${RED}✗ Port 5000 (Admin) is not responding${NC}"
    echo "The service may have failed to start"
fi
echo ""

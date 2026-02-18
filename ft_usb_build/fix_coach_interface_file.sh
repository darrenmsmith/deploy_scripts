#!/bin/bash
# Fix Coach Interface - Replace Broken Version with Working Version
# Issue: Prod has broken coach_interface.py with bad import (settings_manager)
# Date: 2026-01-04

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Fix Coach Interface File - Replace Broken Version${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Backup current broken file
echo -e "${YELLOW}[1] Backing up current (broken) coach_interface.py...${NC}"
BACKUP_FILE="/opt/coach_interface.py.broken_$(date +%Y%m%d_%H%M%S)"
sudo cp /opt/coach_interface.py "$BACKUP_FILE"
echo -e "${GREEN}✓ Backed up to: $BACKUP_FILE${NC}"
echo ""

# Show file info
echo -e "${YELLOW}[2] Current file information:${NC}"
echo "Broken version:"
ls -lh /opt/coach_interface.py
echo ""
echo "Working version from USB:"
ls -lh /mnt/usb/ft_usb_build/coach_interface_working.py
echo ""

# Copy working version
echo -e "${YELLOW}[3] Replacing with working version...${NC}"
sudo cp /mnt/usb/ft_usb_build/coach_interface_working.py /opt/coach_interface.py
sudo chmod 755 /opt/coach_interface.py
sudo chown pi:pi /opt/coach_interface.py
echo -e "${GREEN}✓ File replaced${NC}"
echo ""

# Verify import works
echo -e "${YELLOW}[4] Testing if coach_interface can be imported...${NC}"
cd /opt
python3 -c "import sys; sys.path.insert(0, '/opt'); import coach_interface; print('✓ Import successful')" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ coach_interface imports successfully!${NC}"
else
    echo -e "${RED}✗ Import still failing${NC}"
fi
echo ""

# Kill current process
echo -e "${YELLOW}[5] Stopping current Field Trainer process...${NC}"
PID=$(pgrep -f "field_trainer_main.py" | head -1)
if [ -n "$PID" ]; then
    echo "Killing PID: $PID"
    sudo kill $PID
    sleep 2
    # Check if it died
    if ps -p $PID > /dev/null 2>&1; then
        echo "Process still running, forcing..."
        sudo kill -9 $PID
        sleep 1
    fi
    echo -e "${GREEN}✓ Process stopped${NC}"
else
    echo "No process running"
fi
echo ""

# Start new process
echo -e "${YELLOW}[6] Starting Field Trainer application...${NC}"
cd /opt
nohup python3 /opt/field_trainer_main.py --host 0.0.0.0 --port 5000 --debug 0 > /tmp/field_trainer.log 2>&1 &
NEW_PID=$!
echo "Started with PID: $NEW_PID"
echo ""

# Wait for startup
echo "Waiting 10 seconds for application to start..."
sleep 10
echo ""

# Check process
echo -e "${YELLOW}[7] Verifying process is running...${NC}"
if ps -p $NEW_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Process $NEW_PID is running${NC}"
    ps -p $NEW_PID -f
else
    echo -e "${RED}✗ Process failed to start${NC}"
    echo "Checking startup log:"
    tail -50 /tmp/field_trainer.log
fi
echo ""

# Check ports
echo -e "${YELLOW}[8] Checking listening ports...${NC}"
sudo netstat -tulpn | grep ":500"
echo ""

# Test connectivity
echo -e "${YELLOW}[9] Testing port connectivity...${NC}"
echo -n "Port 5000 (Admin): "
HTTP_5000=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000 2>/dev/null)
if [ "$HTTP_5000" = "200" ] || [ "$HTTP_5000" = "302" ]; then
    echo -e "${GREEN}✓ HTTP $HTTP_5000${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_5000${NC}"
fi

echo -n "Port 5001 (Coach): "
HTTP_5001=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001 2>/dev/null)
if [ "$HTTP_5001" = "200" ] || [ "$HTTP_5001" = "302" ]; then
    echo -e "${GREEN}✓ HTTP $HTTP_5001${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_5001${NC}"
fi
echo ""

# Check recent logs
echo -e "${YELLOW}[10] Checking startup logs for coach interface...${NC}"
tail -100 /tmp/field_trainer.log | grep -i "coach\|5001\|error" | tail -20
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$HTTP_5001" = "200" ] || [ "$HTTP_5001" = "302" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS! ✓✓✓${NC}"
    echo ""
    echo -e "${GREEN}Both interfaces are now working:${NC}"
    echo ""
    echo "  Admin:  http://$(hostname -I | awk '{print $2}'):5000"
    echo "  Coach:  http://$(hostname -I | awk '{print $2}'):5001"
    echo ""
    echo "You can now access the Coach interface from your browser!"
else
    echo -e "${RED}Port 5001 still not responding${NC}"
    echo ""
    echo "Check the startup log:"
    echo "  tail -f /tmp/field_trainer.log"
    echo ""
    echo "Backup of broken file saved at:"
    echo "  $BACKUP_FILE"
fi
echo ""

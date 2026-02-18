#!/bin/bash

################################################################################
# Debug Batman-Mesh Service Failure
# Find out WHY the service won't start
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Batman-Mesh Service Debug"
echo "  Finding out why the service won't start..."
echo "════════════════════════════════════════════════════════════"
echo ""

################################################################################
# Step 1: Check Service Status
################################################################################

echo -e "${BLUE}[1/7] Service Status${NC}"
echo "──────────────────────────────────────"
sudo systemctl status batman-mesh.service --no-pager -l
echo ""

################################################################################
# Step 2: Check Service Logs
################################################################################

echo -e "${BLUE}[2/7] Service Logs (last 30 lines)${NC}"
echo "──────────────────────────────────────"
sudo journalctl -u batman-mesh.service -n 30 --no-pager
echo ""

################################################################################
# Step 3: Check If Service File Exists
################################################################################

echo -e "${BLUE}[3/7] Service File Check${NC}"
echo "──────────────────────────────────────"

if [ -f /etc/systemd/system/batman-mesh.service ]; then
    echo -e "${GREEN}✓ Service file exists${NC}"
    echo ""
    echo "Service file contents:"
    echo "════════════════════════════════════════"
    cat /etc/systemd/system/batman-mesh.service
    echo "════════════════════════════════════════"
else
    echo -e "${RED}✗ Service file NOT found at /etc/systemd/system/batman-mesh.service${NC}"
    echo ""
    echo "Searching for service file..."
    find /etc/systemd -name "*batman*" -o -name "*mesh*" 2>/dev/null
fi
echo ""

################################################################################
# Step 4: Check Startup Script
################################################################################

echo -e "${BLUE}[4/7] Startup Script Check${NC}"
echo "──────────────────────────────────────"

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    echo -e "${GREEN}✓ Startup script exists${NC}"

    if [ -x /usr/local/bin/start-batman-mesh.sh ]; then
        echo -e "${GREEN}✓ Script is executable${NC}"
    else
        echo -e "${RED}✗ Script is NOT executable${NC}"
        ls -la /usr/local/bin/start-batman-mesh.sh
    fi

    echo ""
    echo "Startup script contents:"
    echo "════════════════════════════════════════"
    cat /usr/local/bin/start-batman-mesh.sh
    echo "════════════════════════════════════════"
else
    echo -e "${RED}✗ Startup script NOT found at /usr/local/bin/start-batman-mesh.sh${NC}"
    echo ""
    echo "Searching for startup script..."
    find /usr/local/bin -name "*batman*" -o -name "*mesh*" 2>/dev/null
    find /usr/bin -name "*batman*" -o -name "*mesh*" 2>/dev/null
fi
echo ""

################################################################################
# Step 5: Try Running Startup Script Manually
################################################################################

echo -e "${BLUE}[5/7] Manual Startup Script Test${NC}"
echo "──────────────────────────────────────"

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    echo "Attempting to run startup script manually..."
    echo ""

    sudo bash -x /usr/local/bin/start-batman-mesh.sh
    SCRIPT_EXIT=$?

    echo ""
    echo "Script exit code: $SCRIPT_EXIT"

    if [ $SCRIPT_EXIT -eq 0 ]; then
        echo -e "${GREEN}✓ Script ran successfully${NC}"
    else
        echo -e "${RED}✗ Script failed with exit code $SCRIPT_EXIT${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Cannot test - script not found${NC}"
fi
echo ""

################################################################################
# Step 6: Check Prerequisites
################################################################################

echo -e "${BLUE}[6/7] Prerequisites Check${NC}"
echo "──────────────────────────────────────"

# batman-adv module
if lsmod | grep -q batman_adv; then
    echo -e "${GREEN}✓ batman-adv module loaded${NC}"
else
    echo -e "${RED}✗ batman-adv module NOT loaded${NC}"
    echo "  Try: sudo modprobe batman-adv"
fi

# batctl command
if command -v batctl &>/dev/null; then
    echo -e "${GREEN}✓ batctl command available${NC}"
else
    echo -e "${RED}✗ batctl command NOT found${NC}"
fi

# wlan0 interface
if ip link show wlan0 &>/dev/null; then
    echo -e "${GREEN}✓ wlan0 interface exists${NC}"

    WLAN0_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | awk '{print $2}')
    echo "  wlan0 state: $WLAN0_STATE"

    WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
    echo "  wlan0 type: $WLAN0_TYPE"
else
    echo -e "${RED}✗ wlan0 interface NOT found${NC}"
fi

# bat0 interface
if ip link show bat0 &>/dev/null; then
    echo -e "${GREEN}✓ bat0 interface exists${NC}"

    BAT0_STATE=$(ip link show bat0 | grep -o "state [A-Z]*" | awk '{print $2}')
    echo "  bat0 state: $BAT0_STATE"

    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo "  bat0 IP: $BAT0_IP"
    else
        echo "  bat0 IP: (none)"
    fi
else
    echo -e "${YELLOW}⚠ bat0 interface doesn't exist yet${NC}"
    echo "  (This is normal - created by batman-adv)"
fi

echo ""

################################################################################
# Step 7: Recommendations
################################################################################

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Recommendations${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Determine what's wrong and suggest fixes
SERVICE_EXISTS=false
SCRIPT_EXISTS=false

if [ -f /etc/systemd/system/batman-mesh.service ]; then
    SERVICE_EXISTS=true
fi

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    SCRIPT_EXISTS=true
fi

if [ "$SERVICE_EXISTS" = false ]; then
    echo -e "${RED}ISSUE: Service file missing${NC}"
    echo "Fix: Re-run Phase 4 to create service file"
    echo "  cd /mnt/usb/ft_usb_build"
    echo "  sudo ./ft_build.sh"
    echo "  Choose option 4 (Re-run phase), enter '4'"
    echo ""
fi

if [ "$SCRIPT_EXISTS" = false ]; then
    echo -e "${RED}ISSUE: Startup script missing${NC}"
    echo "Fix: Re-run Phase 4 to create startup script"
    echo "  cd /mnt/usb/ft_usb_build"
    echo "  sudo ./ft_build.sh"
    echo "  Choose option 4 (Re-run phase), enter '4'"
    echo ""
fi

if [ "$SERVICE_EXISTS" = true ] && [ "$SCRIPT_EXISTS" = true ]; then
    echo "Service and script both exist - checking for other issues..."
    echo ""

    # Check if script has errors
    if [ ! -x /usr/local/bin/start-batman-mesh.sh ]; then
        echo -e "${RED}ISSUE: Startup script not executable${NC}"
        echo "Fix: sudo chmod +x /usr/local/bin/start-batman-mesh.sh"
        echo ""
    fi

    # Check if module loaded
    if ! lsmod | grep -q batman_adv; then
        echo -e "${RED}ISSUE: batman-adv module not loaded${NC}"
        echo "Fix: sudo modprobe batman-adv"
        echo ""
    fi

    # Check service status
    if ! systemctl is-enabled --quiet batman-mesh.service 2>/dev/null; then
        echo -e "${YELLOW}NOTICE: Service not enabled${NC}"
        echo "Fix: sudo systemctl enable batman-mesh.service"
        echo ""
    fi

    echo "After fixing issues above, try:"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl start batman-mesh.service"
    echo "  sudo systemctl status batman-mesh.service"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

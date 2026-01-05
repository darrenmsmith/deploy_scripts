#!/bin/bash

################################################################################
# Fix Device0 Mesh Network Issues
# Run this on Device0 Prod to fix wlan0 IBSS mode and wlan1 connection
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Device0 Mesh Network Fix"
echo "  This will fix wlan0 IBSS mode and wlan1 connection"
echo "════════════════════════════════════════════════════════════"
echo ""

################################################################################
# Step 1: Disable NetworkManager and wpa_supplicant for wlan0
################################################################################

echo -e "${BLUE}[1/5] Preventing interference with wlan0...${NC}"
echo ""

# Stop and disable NetworkManager if it's running
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "  Stopping NetworkManager..."
    sudo systemctl stop NetworkManager
    sudo systemctl disable NetworkManager
    echo -e "${GREEN}  ✓ NetworkManager disabled${NC}"
else
    echo "  NetworkManager not running (good)"
fi

# Prevent wpa_supplicant from managing wlan0
echo "  Creating wpa_supplicant@wlan0 disable mask..."
sudo systemctl mask wpa_supplicant@wlan0 2>/dev/null
sudo systemctl stop wpa_supplicant@wlan0 2>/dev/null
echo -e "${GREEN}  ✓ wpa_supplicant masked for wlan0${NC}"

# Kill any existing wpa_supplicant processes on wlan0
sudo pkill -f "wpa_supplicant.*wlan0" 2>/dev/null

echo ""

################################################################################
# Step 2: Restart batman-mesh service
################################################################################

echo -e "${BLUE}[2/5] Restarting batman-mesh service...${NC}"
echo ""

sudo systemctl daemon-reload
sudo systemctl restart batman-mesh.service

sleep 5

if systemctl is-active --quiet batman-mesh.service; then
    echo -e "${GREEN}  ✓ batman-mesh service is running${NC}"
else
    echo -e "${RED}  ✗ batman-mesh service failed${NC}"
    echo "  Checking service status:"
    sudo systemctl status batman-mesh.service --no-pager | head -20
    exit 1
fi

echo ""

################################################################################
# Step 3: Verify wlan0 is in IBSS mode
################################################################################

echo -e "${BLUE}[3/5] Verifying wlan0 IBSS mode...${NC}"
echo ""

sleep 3

WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
if [ "$WLAN0_TYPE" = "IBSS" ]; then
    echo -e "${GREEN}  ✓ wlan0 is in IBSS mode${NC}"

    WLAN0_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')
    if [ -n "$WLAN0_SSID" ]; then
        echo -e "${GREEN}  ✓ Joined IBSS network: $WLAN0_SSID${NC}"
    else
        echo -e "${YELLOW}  ⚠ Not joined to IBSS network yet${NC}"
    fi
else
    echo -e "${RED}  ✗ wlan0 is still in $WLAN0_TYPE mode${NC}"
    echo "  This needs investigation - check /usr/local/bin/start-batman-mesh.sh"
fi

# Check bat0
if ip link show bat0 | grep -q "state UP"; then
    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
    echo -e "${GREEN}  ✓ bat0 is UP with IP: $BAT0_IP${NC}"
else
    echo -e "${RED}  ✗ bat0 is DOWN${NC}"
fi

echo ""

################################################################################
# Step 4: Fix wlan1 connection (if WiFi config exists)
################################################################################

echo -e "${BLUE}[4/5] Fixing wlan1 internet connection...${NC}"
echo ""

if [ -f /etc/wpa_supplicant/wpa_supplicant-wlan1.conf ]; then
    echo "  Found wlan1 WiFi config, restarting services..."

    # Restart wlan1 services
    sudo systemctl restart wlan1-wpa.service
    sleep 10

    if systemctl is-active --quiet wlan1-wpa.service; then
        echo -e "${GREEN}  ✓ wlan1-wpa service running${NC}"
    else
        echo -e "${RED}  ✗ wlan1-wpa service failed${NC}"
        sudo systemctl status wlan1-wpa.service --no-pager | head -15
    fi

    sudo systemctl restart wlan1-dhcp.service
    sleep 15

    if systemctl is-active --quiet wlan1-dhcp.service; then
        echo -e "${GREEN}  ✓ wlan1-dhcp service running${NC}"
    else
        echo -e "${RED}  ✗ wlan1-dhcp service failed${NC}"
        sudo systemctl status wlan1-dhcp.service --no-pager | head -15
    fi

    # Check for IP
    WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$WLAN1_IP" ]; then
        echo -e "${GREEN}  ✓ wlan1 has IP: $WLAN1_IP${NC}"

        # Test internet
        if ping -c 2 8.8.8.8 &>/dev/null; then
            echo -e "${GREEN}  ✓ Internet connection working${NC}"
        else
            echo -e "${YELLOW}  ⚠ No internet connectivity${NC}"
        fi
    else
        echo -e "${RED}  ✗ wlan1 has no IP address${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ No wlan1 WiFi config found${NC}"
    echo "  To configure wlan1, re-run Phase 2"
fi

echo ""

################################################################################
# Step 5: Summary
################################################################################

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Fix Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Final status:"
echo "  wlan0 mode: $(iw dev wlan0 info 2>/dev/null | grep 'type' | awk '{print $2}')"
echo "  wlan0 SSID: $(iw dev wlan0 info 2>/dev/null | grep 'ssid' | awk '{print $2}')"
echo "  bat0 state: $(ip link show bat0 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}')"
echo "  bat0 IP: $(ip addr show bat0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
echo "  wlan1 state: $(ip link show wlan1 2>/dev/null | grep -o 'state [A-Z]*' | awk '{print $2}')"
echo "  wlan1 IP: $(ip addr show wlan1 2>/dev/null | grep 'inet ' | grep -v '169.254' | awk '{print $2}')"

echo ""
echo "Services:"
echo "  batman-mesh: $(systemctl is-active batman-mesh.service 2>/dev/null)"
echo "  wlan1-wpa: $(systemctl is-active wlan1-wpa.service 2>/dev/null)"
echo "  wlan1-dhcp: $(systemctl is-active wlan1-dhcp.service 2>/dev/null)"

echo ""

if [ "$WLAN0_TYPE" = "IBSS" ] && [ -n "$WLAN1_IP" ]; then
    echo -e "${GREEN}✓✓✓ Device0 mesh network is ready for clients! ✓✓✓${NC}"
    echo ""
    echo "You can now build Device1 using the updated scripts."
elif [ "$WLAN0_TYPE" = "IBSS" ]; then
    echo -e "${YELLOW}✓ Mesh network ready, but wlan1 needs configuration${NC}"
    echo "Run Phase 2 on Device0 to configure wlan1 internet"
else
    echo -e "${RED}✗ Still having issues${NC}"
    echo "Check service logs:"
    echo "  sudo journalctl -u batman-mesh -n 50"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

#!/bin/bash

################################################################################
# Fix RF-Kill Issue on Device0
# The batman-mesh service is failing because WiFi is blocked by rfkill
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  RF-Kill Fix for Device0 Mesh Network"
echo "════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}[1/4] Checking RF-Kill status...${NC}"
echo ""
rfkill list
echo ""

echo -e "${BLUE}[2/4] Unblocking WiFi...${NC}"
echo ""
sudo rfkill unblock wifi
echo -e "${GREEN}✓ WiFi unblocked${NC}"
echo ""

echo -e "${BLUE}[3/4] Restarting batman-mesh service...${NC}"
echo ""
sudo systemctl restart batman-mesh.service
sleep 5

if systemctl is-active --quiet batman-mesh.service; then
    echo -e "${GREEN}✓ batman-mesh service is now RUNNING${NC}"
else
    echo -e "${RED}✗ Service still failing${NC}"
    echo ""
    echo "Service status:"
    sudo systemctl status batman-mesh.service --no-pager -l
    echo ""
    echo "Check logs:"
    sudo journalctl -u batman-mesh.service -n 20 --no-pager
    exit 1
fi

echo ""

echo -e "${BLUE}[4/4] Verifying mesh network...${NC}"
echo ""

sleep 3

# Check wlan0
WLAN0_STATE=$(ip link show wlan0 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
WLAN0_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')

echo "wlan0 status:"
echo "  State: $WLAN0_STATE"
echo "  Type: $WLAN0_TYPE"
echo "  SSID: $WLAN0_SSID"

if [ "$WLAN0_STATE" = "UP" ] && [ "$WLAN0_TYPE" = "IBSS" ]; then
    echo -e "${GREEN}  ✓ wlan0 is UP and in IBSS mode${NC}"
else
    echo -e "${YELLOW}  ⚠ wlan0 state/type issue${NC}"
fi

# Check bat0
BAT0_STATE=$(ip link show bat0 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
BAT0_IP=$(ip addr show bat0 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')

echo ""
echo "bat0 status:"
echo "  State: $BAT0_STATE"
echo "  IP: $BAT0_IP"

if [ "$BAT0_STATE" = "UP" ] && [ -n "$BAT0_IP" ]; then
    echo -e "${GREEN}  ✓ bat0 is UP with IP${NC}"
else
    echo -e "${YELLOW}  ⚠ bat0 issue${NC}"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

if [ "$WLAN0_STATE" = "UP" ] && [ "$WLAN0_TYPE" = "IBSS" ] && [ "$BAT0_STATE" = "UP" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS! Device0 mesh network is ready! ✓✓✓${NC}"
    echo ""
    echo "Mesh SSID: $WLAN0_SSID"
    echo "Device0 IP: $BAT0_IP"
    echo ""
    echo "You can now build Device1 and join this mesh network!"
else
    echo -e "${YELLOW}Partial success - some issues remain${NC}"
    echo "Run diagnostics: sudo ./diagnose_device0_mesh.sh"
fi

echo ""
echo "════════════════════════════════════════════════════════════"

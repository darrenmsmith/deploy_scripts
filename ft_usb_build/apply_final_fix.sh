#!/bin/bash

################################################################################
# Apply Final Fix to Device0 Prod
# Replaces startup script with idempotent version
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Apply Final Fix to Device0"
echo "  Replacing startup script with idempotent version"
echo "════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}[1/4] Backing up current startup script...${NC}"
if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    sudo cp /usr/local/bin/start-batman-mesh.sh /usr/local/bin/start-batman-mesh.sh.backup
    echo -e "${GREEN}✓ Backup created: /usr/local/bin/start-batman-mesh.sh.backup${NC}"
else
    echo -e "${YELLOW}⚠ No existing startup script found${NC}"
fi
echo ""

echo -e "${BLUE}[2/4] Installing fixed startup script...${NC}"
if [ -f /mnt/usb/ft_usb_build/start-batman-mesh-FINAL.sh ]; then
    sudo cp /mnt/usb/ft_usb_build/start-batman-mesh-FINAL.sh /usr/local/bin/start-batman-mesh.sh
    sudo chmod +x /usr/local/bin/start-batman-mesh.sh
    echo -e "${GREEN}✓ Fixed startup script installed${NC}"
else
    echo -e "${RED}✗ Fixed script not found on USB${NC}"
    exit 1
fi
echo ""

echo -e "${BLUE}[3/4] Restarting batman-mesh service...${NC}"
sudo systemctl daemon-reload
sudo systemctl restart batman-mesh.service
sleep 5

if systemctl is-active --quiet batman-mesh.service; then
    echo -e "${GREEN}✓ batman-mesh service is ACTIVE${NC}"
else
    echo -e "${YELLOW}⚠ Service not showing as active, but checking interfaces...${NC}"
fi
echo ""

echo -e "${BLUE}[4/4] Verifying mesh network...${NC}"
echo ""

# Check wlan0
WLAN0_STATE=$(ip link show wlan0 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
WLAN0_SSID=$(iw dev wlan0 info 2>/dev/null | grep "ssid" | awk '{print $2}')

echo "wlan0:"
echo "  State: $WLAN0_STATE"
echo "  Type: $WLAN0_TYPE"
echo "  SSID: $WLAN0_SSID"

# Check bat0
BAT0_STATE=$(ip link show bat0 2>/dev/null | grep -o "state [A-Z]*" | awk '{print $2}')
BAT0_IP=$(ip addr show bat0 2>/dev/null | grep "inet " | grep -v "169.254" | awk '{print $2}')

echo ""
echo "bat0:"
echo "  State: $BAT0_STATE"
echo "  IP: $BAT0_IP"

# Check batman-adv
echo ""
echo "batman-adv interfaces:"
sudo batctl if 2>/dev/null

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

# Final status
if [ "$WLAN0_STATE" = "UP" ] && [ "$WLAN0_TYPE" = "IBSS" ] && [ "$BAT0_STATE" = "UP" ] && [ -n "$BAT0_IP" ]; then
    echo -e "${GREEN}✓✓✓ SUCCESS! Device0 mesh network is fully operational! ✓✓✓${NC}"
    echo ""
    echo -e "${CYAN}Mesh Configuration:${NC}"
    echo "  SSID: $WLAN0_SSID"
    echo "  Device0 IP: $BAT0_IP"
    echo ""
    echo -e "${GREEN}Ready to build Device1!${NC}"
    echo ""
    echo "Device1 will join this mesh network in Phase 4."
    echo "Make sure to use SSID: $WLAN0_SSID when prompted."
else
    echo -e "${YELLOW}Partial success - please review status above${NC}"
    echo ""
    echo "Check service logs if needed:"
    echo "  sudo journalctl -u batman-mesh -n 30"
fi

echo ""
echo "════════════════════════════════════════════════════════════"

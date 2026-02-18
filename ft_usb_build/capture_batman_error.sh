#!/bin/bash

################################################################################
# Capture Exact Batman-Mesh Service Error
# Run this on Device0 Prod to see what's failing NOW
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/tmp/batman_error_$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to both screen and log
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Capturing Batman-Mesh Service Error"
echo "  Timestamp: $(date)"
echo "  Log file: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

echo -e "${BLUE}[1/6] Current RF-kill status${NC}"
echo "──────────────────────────────────────"
rfkill list
echo ""

echo -e "${BLUE}[2/6] Current service status${NC}"
echo "──────────────────────────────────────"
sudo systemctl status batman-mesh.service --no-pager -l
echo ""

echo -e "${BLUE}[3/6] Recent service logs${NC}"
echo "──────────────────────────────────────"
sudo journalctl -u batman-mesh.service -n 50 --no-pager
echo ""

echo -e "${BLUE}[4/6] Checking startup script${NC}"
echo "──────────────────────────────────────"
if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    echo "Startup script exists:"
    ls -la /usr/local/bin/start-batman-mesh.sh
    echo ""
    echo "Script contents:"
    echo "════════════════════════════════════════"
    cat /usr/local/bin/start-batman-mesh.sh
    echo "════════════════════════════════════════"
else
    echo -e "${RED}ERROR: Startup script NOT FOUND${NC}"
fi
echo ""

echo -e "${BLUE}[5/6] Manual test of startup script${NC}"
echo "──────────────────────────────────────"
echo "Running startup script with verbose output..."
echo ""

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    sudo bash -x /usr/local/bin/start-batman-mesh.sh 2>&1
    EXIT_CODE=$?

    echo ""
    echo "Script exit code: $EXIT_CODE"

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Script completed successfully${NC}"
    else
        echo -e "${RED}✗ Script failed with exit code $EXIT_CODE${NC}"
    fi
else
    echo -e "${RED}Cannot run - script not found${NC}"
fi
echo ""

echo -e "${BLUE}[6/6] Current interface status${NC}"
echo "──────────────────────────────────────"

echo "wlan0:"
if ip link show wlan0 &>/dev/null; then
    ip addr show wlan0
    echo ""
    iw dev wlan0 info 2>/dev/null
else
    echo "  NOT FOUND"
fi

echo ""
echo "bat0:"
if ip link show bat0 &>/dev/null; then
    ip addr show bat0
    echo ""
    sudo batctl if 2>/dev/null
else
    echo "  NOT FOUND"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""

# Copy to USB if mounted
if [ -d /mnt/usb/ft_usb_build ]; then
    USB_LOG="/mnt/usb/ft_usb_build/batman_error_$(date +%Y%m%d_%H%M%S).log"
    cp "$LOG_FILE" "$USB_LOG"
    echo "Log copied to USB: $USB_LOG"
fi

echo ""
echo "════════════════════════════════════════════════════════════"

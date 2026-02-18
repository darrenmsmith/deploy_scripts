#!/bin/bash

################################################################################
# Force DHCP Renewal on wlan1
# Kills dhcpcd and restarts it to force new DHCP request
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================"
echo "Force DHCP Renewal on wlan1"
echo -e "========================================${NC}"
echo ""

# Setup logging
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/dhcp_renew_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Timestamp: $(date)"
echo "Log: $LOG_FILE"
echo ""

# Kill existing dhcpcd
echo -e "${YELLOW}Step 1: Killing existing dhcpcd...${NC}"
sudo pkill -f 'dhcpcd.*wlan1'
sleep 2

# Flush IP
echo -e "${YELLOW}Step 2: Flushing IP address...${NC}"
sudo ip addr flush dev wlan1

# Bring interface down and up
echo -e "${YELLOW}Step 3: Cycling interface...${NC}"
sudo ip link set wlan1 down
sleep 2
sudo ip link set wlan1 up
sleep 3

# Check WiFi connection
echo -e "${YELLOW}Step 4: Checking WiFi connection...${NC}"
if sudo wpa_cli -i wlan1 status | grep -q "wpa_state=COMPLETED"; then
    SSID=$(sudo wpa_cli -i wlan1 status | grep "^ssid=" | cut -d'=' -f2)
    echo -e "${GREEN}✓ WiFi connected to: $SSID${NC}"
else
    echo -e "${RED}✗ WiFi not connected!${NC}"
    echo "Trying to reconnect..."
    sudo wpa_cli -i wlan1 reassociate
    sleep 5
fi

# Start dhcpcd in foreground with verbose output
echo ""
echo -e "${YELLOW}Step 5: Starting dhcpcd with verbose output...${NC}"
echo "Running: dhcpcd -4 -d wlan1 (will timeout after 60 seconds)"
echo "Watch for DHCP server responses..."
echo ""

sudo timeout 60 dhcpcd -4 -d wlan1

echo ""
echo -e "${YELLOW}Step 6: Checking results...${NC}"

# Check IP
WLAN1_IP=$(ip addr show wlan1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

if [ -n "$WLAN1_IP" ]; then
    if [[ "$WLAN1_IP" == 169.254.* ]]; then
        echo -e "${RED}✗ Got IPv4LL address: $WLAN1_IP (no DHCP)${NC}"
        echo ""
        echo "Possible causes:"
        echo "  1. DHCP server not responding"
        echo "  2. MAC address filtered on router: $(cat /sys/class/net/wlan1/address)"
        echo "  3. DHCP pool exhausted"
        echo "  4. Router DHCP disabled"
        echo "  5. WiFi signal too weak (-73 dBm is borderline)"
    else
        echo -e "${GREEN}✓ Got valid IP: $WLAN1_IP${NC}"

        # Test gateway
        GATEWAY=$(ip route | grep "default.*wlan1" | awk '{print $3}')
        if [ -n "$GATEWAY" ]; then
            echo "  Gateway: $GATEWAY"
            if ping -c 3 -W 2 "$GATEWAY" &>/dev/null; then
                echo -e "  ${GREEN}✓ Gateway reachable${NC}"
            else
                echo -e "  ${RED}✗ Gateway unreachable${NC}"
            fi
        fi

        # Test internet
        if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
            echo -e "  ${GREEN}✓ Internet working!${NC}"
        else
            echo -e "  ${RED}✗ No internet${NC}"
        fi
    fi
else
    echo -e "${RED}✗ No IP address${NC}"
fi

echo ""
echo -e "${BLUE}========================================"
echo "Complete - Log saved to:"
echo "$LOG_FILE"
echo -e "========================================${NC}"

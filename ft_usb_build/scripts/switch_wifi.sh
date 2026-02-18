#!/bin/bash

################################################################################
# Switch WiFi Network
# Changes wlan1 to a different WiFi network and tests DHCP
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================"
echo "Switch WiFi Network for wlan1"
echo -e "========================================${NC}"
echo ""

# Setup logging
LOG_DIR="/mnt/usb/install_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/wifi_switch_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Timestamp: $(date)"
echo "Log: $LOG_FILE"
echo ""

# Get new WiFi credentials
echo -e "${YELLOW}Enter new WiFi credentials:${NC}"
read -p "WiFi SSID: " NEW_SSID
read -sp "WiFi Password: " NEW_PASSWORD
echo ""
echo ""

if [ -z "$NEW_SSID" ] || [ -z "$NEW_PASSWORD" ]; then
    echo -e "${RED}✗ SSID and password required!${NC}"
    exit 1
fi

# Backup old config
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
echo -e "${YELLOW}Step 1: Backing up old config...${NC}"
sudo cp "$WPA_CONF" "${WPA_CONF}.backup.${TIMESTAMP}"
echo -e "${GREEN}✓ Backed up to ${WPA_CONF}.backup.${TIMESTAMP}${NC}"
echo ""

# Create new config
echo -e "${YELLOW}Step 2: Creating new WiFi config...${NC}"
sudo tee "$WPA_CONF" > /dev/null << EOF
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$NEW_SSID"
    psk="$NEW_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF

sudo chmod 600 "$WPA_CONF"
echo -e "${GREEN}✓ Config created for: $NEW_SSID${NC}"
echo ""

# Stop existing services
echo -e "${YELLOW}Step 3: Stopping wlan1 services...${NC}"
sudo systemctl stop wlan1-dhcp.service 2>/dev/null
sudo systemctl stop wlan1-wpa.service 2>/dev/null
sleep 2

# Kill any running processes
sudo pkill -f 'dhcpcd.*wlan1'
sudo pkill -f 'wpa_supplicant.*wlan1'
sleep 2

echo -e "${GREEN}✓ Services stopped${NC}"
echo ""

# Reset interface
echo -e "${YELLOW}Step 4: Resetting wlan1 interface...${NC}"
sudo ip link set wlan1 down
sudo ip addr flush dev wlan1
sleep 2
sudo ip link set wlan1 up
sleep 2
echo -e "${GREEN}✓ Interface reset${NC}"
echo ""

# Start wpa_supplicant
echo -e "${YELLOW}Step 5: Connecting to new WiFi network...${NC}"
sudo wpa_supplicant -B -i wlan1 -c "$WPA_CONF" -P /run/wpa_supplicant-wlan1.pid

echo "Waiting for WiFi connection (15 seconds)..."
sleep 15

# Check connection
if sudo wpa_cli -i wlan1 status | grep -q "wpa_state=COMPLETED"; then
    CONNECTED_SSID=$(sudo wpa_cli -i wlan1 status | grep "^ssid=" | cut -d'=' -f2)
    echo -e "${GREEN}✓ Connected to: $CONNECTED_SSID${NC}"

    # Show signal strength
    echo ""
    echo "Connection details:"
    sudo iw dev wlan1 link | grep -E "SSID|freq|signal|rx bitrate|tx bitrate"
    echo ""
else
    echo -e "${RED}✗ Failed to connect to WiFi!${NC}"
    echo ""
    echo "Possible issues:"
    echo "  1. Wrong password"
    echo "  2. SSID out of range"
    echo "  3. Incompatible security settings"
    echo ""
    echo "Restoring old config..."
    sudo cp "${WPA_CONF}.backup.${TIMESTAMP}" "$WPA_CONF"
    exit 1
fi

# Start DHCP
echo -e "${YELLOW}Step 6: Getting IP address via DHCP...${NC}"
echo "Running dhcpcd with verbose output (60 second timeout)..."
echo ""

sudo timeout 60 dhcpcd -4 -d wlan1 &
DHCPCD_PID=$!

# Wait for IP
echo "Waiting 30 seconds for DHCP..."
sleep 30

# Check results
echo ""
echo -e "${YELLOW}Step 7: Checking results...${NC}"

WLAN1_IP=$(ip addr show wlan1 | grep "inet " | grep -v "169.254" | awk '{print $2}' | cut -d'/' -f1)

if [ -n "$WLAN1_IP" ]; then
    echo -e "${GREEN}✓ IP obtained: $WLAN1_IP${NC}"

    # Get gateway
    GATEWAY=$(ip route | grep "default.*wlan1" | awk '{print $3}')
    if [ -n "$GATEWAY" ]; then
        echo "  Gateway: $GATEWAY"

        # Test gateway
        if ping -c 3 -W 2 "$GATEWAY" &>/dev/null; then
            echo -e "  ${GREEN}✓ Gateway reachable${NC}"
        else
            echo -e "  ${YELLOW}⚠ Gateway not responding${NC}"
        fi

        # Test internet
        if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
            echo -e "  ${GREEN}✓ Internet working!${NC}"
        else
            echo -e "  ${RED}✗ No internet${NC}"
        fi

        # Test DNS
        if host google.com &>/dev/null; then
            echo -e "  ${GREEN}✓ DNS working${NC}"
        else
            echo -e "  ${RED}✗ DNS not working${NC}"
        fi
    fi
else
    # Check for IPv4LL
    IPV4LL=$(ip addr show wlan1 | grep "inet 169.254" | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$IPV4LL" ]; then
        echo -e "${RED}✗ Only got IPv4LL address: $IPV4LL${NC}"
        echo ""
        echo "DHCP server did not respond!"
        echo "Check router DHCP settings for this network."
    else
        echo -e "${RED}✗ No IP address obtained${NC}"
    fi
fi

echo ""

# Kill background dhcpcd if still running
if ps -p $DHCPCD_PID > /dev/null 2>&1; then
    kill $DHCPCD_PID 2>/dev/null
fi

# Start services for permanent use
echo -e "${YELLOW}Step 8: Starting systemd services...${NC}"
sudo systemctl start wlan1-wpa.service
sleep 5
sudo systemctl start wlan1-dhcp.service
sleep 5

echo -e "${GREEN}✓ Services started${NC}"
echo ""

# Final status
echo -e "${BLUE}========================================"
echo "WiFi Switch Complete"
echo -e "========================================${NC}"
echo ""
echo "Current configuration:"
echo "  SSID: $NEW_SSID"
echo "  IP: $(ip addr show wlan1 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
echo "  Services:"
systemctl is-active wlan1-wpa.service && echo "    wlan1-wpa: active" || echo "    wlan1-wpa: inactive"
systemctl is-active wlan1-dhcp.service && echo "    wlan1-dhcp: active" || echo "    wlan1-dhcp: inactive"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""

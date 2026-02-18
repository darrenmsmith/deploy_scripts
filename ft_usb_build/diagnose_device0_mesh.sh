#!/bin/bash

################################################################################
# Device0 Mesh Network Diagnostic Script
# Run this on Device0 Prod to verify mesh network is ready for clients
# Creates detailed log file for analysis
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Create log file
LOG_FILE="/tmp/device0_mesh_diagnostic_$(date +%Y%m%d_%H%M%S).log"

# Start logging (tee to both screen and file)
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Device0 Mesh Network Diagnostics"
echo "  Timestamp: $(date)"
echo "  Log file: $LOG_FILE"
echo "════════════════════════════════════════════════════════════"
echo ""

################################################################################
# Step 1: Check Hostname
################################################################################

echo -e "${BLUE}[1/10] Checking hostname...${NC}"
HOSTNAME=$(hostname)
echo "  Hostname: $HOSTNAME"

if [[ $HOSTNAME =~ Device0 ]] || [[ $HOSTNAME =~ device0 ]]; then
    echo -e "${GREEN}  ✓ Hostname matches Device0${NC}"
else
    echo -e "${YELLOW}  ⚠ Hostname is '$HOSTNAME' (expected Device0)${NC}"
fi
echo ""

################################################################################
# Step 2: Check WiFi Interfaces
################################################################################

echo -e "${BLUE}[2/10] Checking WiFi interfaces...${NC}"
echo ""

# wlan0 (onboard WiFi - should be mesh)
if ip link show wlan0 &>/dev/null; then
    WLAN0_MAC=$(cat /sys/class/net/wlan0/address 2>/dev/null)
    echo -e "${GREEN}  ✓ wlan0 found: $WLAN0_MAC${NC}"

    echo "  ──────────────────────────────────────"
    echo "  wlan0 IP address details:"
    ip addr show wlan0 | sed 's/^/    /'

    echo ""
    echo "  wlan0 wireless info:"
    iw dev wlan0 info 2>/dev/null | sed 's/^/    /' || echo "    (iw command failed)"
    echo "  ──────────────────────────────────────"
else
    echo -e "${RED}  ✗ wlan0 NOT FOUND${NC}"
    echo "  Available interfaces:"
    ip link show | grep "^[0-9]" | awk '{print "    " $2}'
fi

echo ""

# wlan1 (USB WiFi - should be home network for SSH/internet)
if ip link show wlan1 &>/dev/null; then
    WLAN1_MAC=$(cat /sys/class/net/wlan1/address 2>/dev/null)
    echo -e "${GREEN}  ✓ wlan1 found: $WLAN1_MAC${NC}"

    echo "  ──────────────────────────────────────"
    echo "  wlan1 IP address details:"
    ip addr show wlan1 | sed 's/^/    /'

    echo ""
    echo "  wlan1 wireless info:"
    iw dev wlan1 info 2>/dev/null | sed 's/^/    /' || echo "    (iw command failed)"

    # Check if wlan1 is connected to a network
    WLAN1_SSID=$(iw dev wlan1 info 2>/dev/null | grep ssid | awk '{print $2}')
    if [ -n "$WLAN1_SSID" ]; then
        echo ""
        echo -e "${GREEN}    Connected to WiFi: $WLAN1_SSID${NC}"
    else
        echo ""
        echo -e "${RED}    NOT connected to any WiFi network${NC}"
    fi
    echo "  ──────────────────────────────────────"
else
    echo -e "${YELLOW}  ⚠ wlan1 NOT FOUND (USB WiFi may not be connected)${NC}"
fi
echo ""

################################################################################
# Step 3: Check batman-adv Module
################################################################################

echo -e "${BLUE}[3/10] Checking batman-adv kernel module...${NC}"

if lsmod | grep -q batman_adv; then
    echo -e "${GREEN}  ✓ batman-adv module is loaded${NC}"
    BATCTL_VERSION=$(batctl -v 2>/dev/null | head -1)
    if [ -n "$BATCTL_VERSION" ]; then
        echo "  Version: $BATCTL_VERSION"
    fi
else
    echo -e "${RED}  ✗ batman-adv module NOT loaded${NC}"
    echo "  Try: sudo modprobe batman-adv"
fi
echo ""

################################################################################
# Step 4: Check batman-mesh Service
################################################################################

echo -e "${BLUE}[4/10] Checking batman-mesh service...${NC}"

if systemctl list-unit-files | grep -q batman-mesh; then
    echo -e "${GREEN}  ✓ batman-mesh service exists${NC}"

    if systemctl is-active --quiet batman-mesh; then
        echo -e "${GREEN}  ✓ batman-mesh service is RUNNING${NC}"
    else
        echo -e "${RED}  ✗ batman-mesh service is NOT running${NC}"
        echo "  Status:"
        systemctl status batman-mesh --no-pager | head -15 | sed 's/^/    /'
    fi

    if systemctl is-enabled --quiet batman-mesh 2>/dev/null; then
        echo -e "${GREEN}  ✓ batman-mesh service is enabled (auto-start)${NC}"
    else
        echo -e "${YELLOW}  ⚠ batman-mesh service is NOT enabled${NC}"
    fi
else
    echo -e "${RED}  ✗ batman-mesh service NOT FOUND${NC}"
    echo "  Looking for mesh startup scripts..."

    if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
        echo -e "${GREEN}  ✓ Found: /usr/local/bin/start-batman-mesh.sh${NC}"
    else
        echo -e "${RED}  ✗ Not found: /usr/local/bin/start-batman-mesh.sh${NC}"
    fi

    if [ -f /etc/systemd/system/batman-mesh.service ]; then
        echo -e "${GREEN}  ✓ Found: /etc/systemd/system/batman-mesh.service${NC}"
    else
        echo -e "${RED}  ✗ Not found: /etc/systemd/system/batman-mesh.service${NC}"
    fi
fi
echo ""

################################################################################
# Step 5: Check wlan0 Configuration
################################################################################

echo -e "${BLUE}[5/10] Checking wlan0 configuration...${NC}"

if ip link show wlan0 &>/dev/null; then
    WLAN0_STATE=$(ip link show wlan0 | grep -o "state [A-Z]*" | awk '{print $2}')
    echo "  State: $WLAN0_STATE"

    # Check if wlan0 is up
    if ip link show wlan0 | grep -q "state UP"; then
        echo -e "${GREEN}  ✓ wlan0 is UP${NC}"
    else
        echo -e "${RED}  ✗ wlan0 is DOWN${NC}"
        echo "  Try: sudo ip link set wlan0 up"
    fi

    # Check wlan0 mode
    WLAN0_INFO=$(iw dev wlan0 info 2>/dev/null)
    if [ -n "$WLAN0_INFO" ]; then
        WLAN0_TYPE=$(echo "$WLAN0_INFO" | grep "type" | awk '{print $2}')
        echo "  Type: $WLAN0_TYPE"

        if [ "$WLAN0_TYPE" = "IBSS" ]; then
            echo -e "${GREEN}  ✓ wlan0 is in IBSS (ad-hoc) mode${NC}"
        else
            echo -e "${RED}  ✗ wlan0 is NOT in IBSS mode (currently: $WLAN0_TYPE)${NC}"
        fi

        # Show SSID if joined
        WLAN0_SSID=$(echo "$WLAN0_INFO" | grep "ssid" | cut -d' ' -f2-)
        if [ -n "$WLAN0_SSID" ]; then
            echo -e "${GREEN}  ✓ Joined IBSS network: $WLAN0_SSID${NC}"
        else
            echo -e "${RED}  ✗ Not joined to any IBSS network${NC}"
        fi
    fi
fi
echo ""

################################################################################
# Step 6: Check bat0 Interface
################################################################################

echo -e "${BLUE}[6/10] Checking bat0 interface...${NC}"

if ip link show bat0 &>/dev/null; then
    echo -e "${GREEN}  ✓ bat0 interface exists${NC}"

    # Check if bat0 is up
    if ip link show bat0 | grep -q "state UP"; then
        echo -e "${GREEN}  ✓ bat0 is UP${NC}"
    else
        echo -e "${RED}  ✗ bat0 is DOWN${NC}"
    fi

    # Check bat0 IP address
    BAT0_IP=$(ip addr show bat0 | grep "inet " | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo -e "${GREEN}  ✓ bat0 IP: $BAT0_IP${NC}"

        if [[ "$BAT0_IP" == "192.168.99.100"* ]]; then
            echo -e "${GREEN}  ✓ Correct Device0 IP address${NC}"
        else
            echo -e "${YELLOW}  ⚠ Expected 192.168.99.100/24${NC}"
        fi
    else
        echo -e "${RED}  ✗ bat0 has NO IP address${NC}"
    fi
else
    echo -e "${RED}  ✗ bat0 interface NOT FOUND${NC}"
    echo "  batman-adv may not be configured correctly"
fi
echo ""

################################################################################
# Step 7: Check BATMAN-adv Interfaces
################################################################################

echo -e "${BLUE}[7/10] Checking BATMAN-adv interface configuration...${NC}"

if command -v batctl &>/dev/null; then
    BATCTL_IF=$(sudo batctl if 2>/dev/null)
    if [ -n "$BATCTL_IF" ]; then
        echo -e "${GREEN}  ✓ BATMAN-adv interfaces:${NC}"
        echo "$BATCTL_IF" | sed 's/^/    /'
    else
        echo -e "${RED}  ✗ No interfaces added to BATMAN-adv${NC}"
        echo "  Try: sudo batctl if add wlan0"
    fi
else
    echo -e "${RED}  ✗ batctl command not found${NC}"
fi
echo ""

################################################################################
# Step 8: Check Mesh Neighbors
################################################################################

echo -e "${BLUE}[8/10] Checking mesh neighbors...${NC}"

if command -v batctl &>/dev/null; then
    NEIGHBORS=$(sudo batctl n 2>/dev/null)
    if [ -n "$NEIGHBORS" ]; then
        echo -e "${GREEN}  Mesh neighbors:${NC}"
        echo "$NEIGHBORS" | sed 's/^/    /'
    else
        echo -e "${YELLOW}  ⚠ No mesh neighbors found${NC}"
        echo "  This is normal if no clients have joined yet"
    fi
else
    echo -e "${YELLOW}  ⚠ batctl not available${NC}"
fi
echo ""

################################################################################
# Step 9: Check Mesh Startup Script
################################################################################

echo -e "${BLUE}[9/10] Checking mesh startup script configuration...${NC}"

if [ -f /usr/local/bin/start-batman-mesh.sh ]; then
    echo -e "${GREEN}  ✓ Found startup script${NC}"
    echo ""
    echo "  Full 'ibss join' command from script:"
    echo "  ────────────────────────────────────────"
    grep "ibss join" /usr/local/bin/start-batman-mesh.sh | sed 's/^/    /'
    echo "  ────────────────────────────────────────"
    echo ""

    echo "  Mesh configuration from script:"
    echo "  ────────────────────────────────────────"

    # Extract SSID
    MESH_SSID=$(grep -E "MESH_SSID=|ibss join" /usr/local/bin/start-batman-mesh.sh | head -1 | sed 's/.*MESH_SSID=//' | sed 's/"//g' | awk '{print $4}')
    if [ -z "$MESH_SSID" ]; then
        MESH_SSID=$(grep "ibss join" /usr/local/bin/start-batman-mesh.sh | awk '{print $4}' | sed 's/"//g')
    fi
    echo "  SSID: $MESH_SSID"

    # Extract channel/frequency
    MESH_FREQ=$(grep "ibss join" /usr/local/bin/start-batman-mesh.sh | awk '{print $5}')
    if [ -n "$MESH_FREQ" ]; then
        MESH_CHANNEL=$(( (MESH_FREQ - 2407) / 5 ))
        echo "  Frequency: $MESH_FREQ MHz (Channel $MESH_CHANNEL)"
    fi

    # Extract BSSID
    MESH_BSSID=$(grep "BSSID" /usr/local/bin/start-batman-mesh.sh | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" | head -1)
    if [ -n "$MESH_BSSID" ]; then
        echo "  BSSID: $MESH_BSSID"
    fi

    echo "  ────────────────────────────────────────"
    echo ""
    echo -e "${CYAN}  IMPORTANT: Clients must use SSID '$MESH_SSID' to join${NC}"
    echo ""
    echo "  Full startup script contents:"
    echo "  ════════════════════════════════════════"
    cat /usr/local/bin/start-batman-mesh.sh | sed 's/^/    /'
    echo "  ════════════════════════════════════════"
else
    echo -e "${RED}  ✗ Startup script not found${NC}"
fi
echo ""

################################################################################
# Step 10: Summary and Recommendations
################################################################################

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Summary and Recommendations${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Determine overall status
CRITICAL_ISSUES=0
WARNINGS=0

# Check critical requirements
if ! ip link show wlan0 &>/dev/null; then
    echo -e "${RED}✗ CRITICAL: wlan0 interface not found${NC}"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

if ! lsmod | grep -q batman_adv; then
    echo -e "${RED}✗ CRITICAL: batman-adv module not loaded${NC}"
    echo "  Fix: sudo modprobe batman-adv"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

if ! systemctl is-active --quiet batman-mesh 2>/dev/null; then
    echo -e "${RED}✗ CRITICAL: batman-mesh service not running${NC}"
    echo "  Fix: sudo systemctl start batman-mesh"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

if ! ip link show bat0 &>/dev/null; then
    echo -e "${RED}✗ CRITICAL: bat0 interface not found${NC}"
    echo "  Fix: Check batman-mesh service is running"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

BAT0_IP=$(ip addr show bat0 2>/dev/null | grep "inet " | awk '{print $2}')
if [ -z "$BAT0_IP" ]; then
    echo -e "${RED}✗ CRITICAL: bat0 has no IP address${NC}"
    echo "  Fix: sudo ip addr add 192.168.99.100/24 dev bat0"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

WLAN0_TYPE=$(iw dev wlan0 info 2>/dev/null | grep "type" | awk '{print $2}')
if [ "$WLAN0_TYPE" != "IBSS" ]; then
    echo -e "${YELLOW}⚠ WARNING: wlan0 not in IBSS mode${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
if [ $CRITICAL_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ Device0 mesh network appears ready for clients! ✓✓✓${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Note the mesh SSID from above"
    echo "  2. Start building Device1"
    echo "  3. Use the same mesh SSID when prompted in Phase 4"
else
    echo -e "${RED}✗✗✗ Found $CRITICAL_ISSUES critical issues ✗✗✗${NC}"
    echo ""
    echo "You must fix these issues before clients can join."
    echo ""
    echo "Quick fix commands:"
    echo "  sudo systemctl restart batman-mesh"
    echo "  sudo systemctl status batman-mesh"
fi

if [ $WARNINGS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Found $WARNINGS warnings (may not be critical)${NC}"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

################################################################################
# Copy log to USB for analysis
################################################################################

echo ""
echo "Copying log to USB drive..."

if [ -d "/mnt/usb/ft_usb_build" ]; then
    USB_LOG="/mnt/usb/ft_usb_build/device0_mesh_diagnostic_$(date +%Y%m%d_%H%M%S).log"
    cp "$LOG_FILE" "$USB_LOG" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ Log copied to: $USB_LOG"
        echo ""
        echo "You can now:"
        echo "  1. Unmount USB from Device0 Prod"
        echo "  2. Mount USB on dev system"
        echo "  3. Share the log file for analysis"
    else
        echo "⚠ Could not copy to USB (is it mounted?)"
        echo "  Log saved locally at: $LOG_FILE"
    fi
else
    echo "⚠ USB not mounted at /mnt/usb"
    echo "  Log saved locally at: $LOG_FILE"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

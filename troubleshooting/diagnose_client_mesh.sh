#!/bin/bash

################################################################################
# Client Mesh Network Diagnostic Script
# Run this script on a client device that's not connecting after reboot
################################################################################

echo "========================================"
echo "Field Trainer Client Mesh Diagnostics"
echo "========================================"
echo ""
echo "Device: $(hostname)"
echo "Date: $(date)"
echo ""

################################################################################
# Check Hostname
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Hostname Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"

if [[ $HOSTNAME =~ Device([1-5]) ]]; then
    DEVICE_NUM="${BASH_REMATCH[1]}"
    EXPECTED_IP="192.168.99.10${DEVICE_NUM}"
    echo "✓ Valid client hostname"
    echo "  Device Number: $DEVICE_NUM"
    echo "  Expected IP: $EXPECTED_IP"
else
    echo "✗ Invalid hostname (expected Device1-5)"
fi
echo ""

################################################################################
# Check Systemd Services
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Systemd Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if batman-mesh-client service exists
if [ -f /etc/systemd/system/batman-mesh-client.service ]; then
    echo "✓ batman-mesh-client.service file exists"

    # Check if enabled
    if systemctl is-enabled batman-mesh-client.service &>/dev/null; then
        echo "✓ batman-mesh-client.service is ENABLED"
    else
        echo "✗ batman-mesh-client.service is NOT enabled"
        echo "  Fix: sudo systemctl enable batman-mesh-client.service"
    fi

    # Check if active
    if systemctl is-active batman-mesh-client.service &>/dev/null; then
        echo "✓ batman-mesh-client.service is ACTIVE"
    else
        echo "✗ batman-mesh-client.service is NOT active"
        echo "  Status:"
        systemctl status batman-mesh-client.service --no-pager
    fi
else
    echo "✗ batman-mesh-client.service file MISSING"
    echo "  Expected: /etc/systemd/system/batman-mesh-client.service"
    echo "  Fix: Re-run Phase 4 mesh setup"
fi
echo ""

# Check field-client service
if [ -f /etc/systemd/system/field-client.service ]; then
    echo "✓ field-client.service file exists"

    if systemctl is-enabled field-client.service &>/dev/null; then
        echo "✓ field-client.service is ENABLED"
    else
        echo "✗ field-client.service is NOT enabled"
    fi

    if systemctl is-active field-client.service &>/dev/null; then
        echo "✓ field-client.service is ACTIVE"
    else
        echo "✗ field-client.service is NOT active"
    fi
else
    echo "ℹ field-client.service not found (install with Phase 5)"
fi
echo ""

################################################################################
# Check Startup Scripts
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Startup Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "✓ start-batman-mesh-client.sh exists"
    if [ -x /usr/local/bin/start-batman-mesh-client.sh ]; then
        echo "✓ start-batman-mesh-client.sh is executable"
    else
        echo "✗ start-batman-mesh-client.sh is NOT executable"
        echo "  Fix: sudo chmod +x /usr/local/bin/start-batman-mesh-client.sh"
    fi
else
    echo "✗ start-batman-mesh-client.sh MISSING"
fi

if [ -f /usr/local/bin/stop-batman-mesh-client.sh ]; then
    echo "✓ stop-batman-mesh-client.sh exists"
else
    echo "✗ stop-batman-mesh-client.sh MISSING"
fi
echo ""

################################################################################
# Check Network Interfaces
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Network Interfaces"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check wlan0
if ip link show wlan0 &>/dev/null; then
    WLAN0_STATE=$(ip link show wlan0 | grep -oP 'state \K\w+')
    echo "wlan0 interface: EXISTS"
    echo "  State: $WLAN0_STATE"

    # Check if in IBSS mode
    if iw dev wlan0 info | grep -q "type IBSS"; then
        echo "  ✓ Mode: IBSS (Ad-hoc)"
        SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
        echo "  SSID: $SSID"
    else
        CURRENT_MODE=$(iw dev wlan0 info | grep type | awk '{print $2}')
        echo "  ✗ Mode: $CURRENT_MODE (expected IBSS)"
    fi
else
    echo "✗ wlan0 interface NOT FOUND"
fi
echo ""

# Check bat0
if ip link show bat0 &>/dev/null; then
    BAT0_STATE=$(ip link show bat0 | grep -oP 'state \K\w+')
    echo "bat0 interface: EXISTS"
    echo "  State: $BAT0_STATE"

    BAT0_IP=$(ip addr show bat0 | grep 'inet ' | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo "  ✓ IP Address: $BAT0_IP"
    else
        echo "  ✗ No IP address assigned"
    fi
else
    echo "✗ bat0 interface NOT FOUND"
    echo "  This means batman-adv is not active"
fi
echo ""

################################################################################
# Check BATMAN-adv
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. BATMAN-adv Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check module loaded
if lsmod | grep -q batman_adv; then
    echo "✓ batman-adv module LOADED"
else
    echo "✗ batman-adv module NOT loaded"
    echo "  Fix: sudo modprobe batman-adv"
fi

# Check batctl interfaces
echo ""
echo "batctl interfaces:"
sudo batctl if 2>&1 || echo "  No interfaces added to batman-adv"

# Check neighbors
echo ""
echo "batctl neighbors:"
sudo batctl n 2>&1 || echo "  Cannot check neighbors"

echo ""

################################################################################
# Check Connectivity
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Network Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEVICE0_IP="192.168.99.100"

echo "Testing ping to Device0 ($DEVICE0_IP)..."
if ping -c 3 -W 5 $DEVICE0_IP &>/dev/null; then
    echo "✓ Can reach Device0"
else
    echo "✗ Cannot reach Device0"
    echo "  This is the primary issue - no mesh connectivity"
fi
echo ""

################################################################################
# Check Recent Logs
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Recent Service Logs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "batman-mesh-client service logs (last 20 lines):"
echo "─────────────────────────────────────────"
sudo journalctl -u batman-mesh-client -n 20 --no-pager 2>/dev/null || echo "No logs found"

echo ""
echo "field-client service logs (last 10 lines):"
echo "─────────────────────────────────────────"
sudo journalctl -u field-client -n 10 --no-pager 2>/dev/null || echo "No logs found (service may not be installed)"

echo ""

################################################################################
# Summary and Recommendations
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Summary and Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Common Issues and Fixes:"
echo ""
echo "1. Service not enabled:"
echo "   sudo systemctl enable batman-mesh-client.service"
echo "   sudo systemctl start batman-mesh-client.service"
echo ""
echo "2. Service fails to start on boot:"
echo "   Check logs: sudo journalctl -u batman-mesh-client -b"
echo "   Try manual start: sudo /usr/local/bin/start-batman-mesh-client.sh"
echo ""
echo "3. wlan0 not in IBSS mode:"
echo "   sudo systemctl restart batman-mesh-client.service"
echo ""
echo "4. No neighbors visible:"
echo "   Check Device0 is running: ssh pi@192.168.99.100 'sudo batctl n'"
echo "   Verify SSID matches Device0"
echo ""
echo "5. Service enabled but not starting:"
echo "   Check service dependencies: systemctl list-dependencies batman-mesh-client"
echo "   May need to add 'Wants=network-online.target' to service file"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostics Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

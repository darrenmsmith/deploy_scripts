#!/bin/bash

################################################################################
# Client Mesh Network Boot Fix Script
# Run this script on a client device to fix boot connectivity issues
################################################################################

echo "========================================"
echo "Field Trainer Client Mesh Boot Fix"
echo "========================================"
echo ""

# Check if running on a client device
HOSTNAME=$(hostname)
if [[ ! $HOSTNAME =~ Device([1-5]) ]]; then
    echo "✗ Error: This script must be run on a client device (Device1-5)"
    echo "  Current hostname: $HOSTNAME"
    exit 1
fi

DEVICE_NUM="${BASH_REMATCH[1]}"
echo "✓ Running on: Device${DEVICE_NUM}"
echo ""

################################################################################
# Check and Fix Service File
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Checking Service Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f /etc/systemd/system/batman-mesh-client.service ]; then
    echo "✗ Service file missing - this shouldn't happen after Phase 4"
    echo "  Please re-run Phase 4 mesh setup"
    exit 1
fi

echo "✓ Service file exists"
echo ""

# Check current service configuration
echo "Current service file:"
cat /etc/systemd/system/batman-mesh-client.service
echo ""

################################################################################
# Improve Service Configuration
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Updating Service Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Creating improved service configuration..."
echo ""

sudo tee /etc/systemd/system/batman-mesh-client.service > /dev/null << 'EOF'
[Unit]
Description=BATMAN-adv Mesh Network (Client)
After=network.target network-online.target
Wants=network-online.target
Before=field-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file updated with:"
echo "  • Waits for network to be online"
echo "  • Starts before field-client service"
echo "  • Auto-restart on failure"
echo "  • 10 second restart delay"
echo ""

################################################################################
# Reload and Enable Service
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Enabling and Starting Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling batman-mesh-client service..."
sudo systemctl enable batman-mesh-client.service

echo "Starting batman-mesh-client service..."
sudo systemctl start batman-mesh-client.service

echo ""
sleep 3

################################################################################
# Verify Service Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if service is enabled
if systemctl is-enabled batman-mesh-client.service &>/dev/null; then
    echo "✓ Service is ENABLED (will start on boot)"
else
    echo "✗ Service is NOT enabled"
    exit 1
fi

# Check if service is active
if systemctl is-active batman-mesh-client.service &>/dev/null; then
    echo "✓ Service is ACTIVE (currently running)"
else
    echo "✗ Service is NOT active"
    echo ""
    echo "Service status:"
    sudo systemctl status batman-mesh-client.service --no-pager
    echo ""
    echo "Recent logs:"
    sudo journalctl -u batman-mesh-client -n 30 --no-pager
    exit 1
fi

# Check bat0 interface
echo ""
if ip link show bat0 &>/dev/null; then
    echo "✓ bat0 interface exists"
    BAT0_IP=$(ip addr show bat0 | grep 'inet ' | awk '{print $2}')
    if [ -n "$BAT0_IP" ]; then
        echo "✓ bat0 has IP: $BAT0_IP"
    else
        echo "⚠ bat0 has no IP address"
    fi
else
    echo "✗ bat0 interface does not exist"
fi

# Check wlan0 mode
echo ""
if iw dev wlan0 info | grep -q "type IBSS"; then
    echo "✓ wlan0 is in IBSS mode"
    SSID=$(iw dev wlan0 info | grep ssid | awk '{print $2}')
    echo "  SSID: $SSID"
else
    echo "✗ wlan0 is NOT in IBSS mode"
fi

# Check neighbors
echo ""
echo "Mesh neighbors:"
sudo batctl n

# Test connectivity
echo ""
DEVICE0_IP="192.168.99.100"
echo "Testing connectivity to Device0 ($DEVICE0_IP)..."
if ping -c 3 -W 5 $DEVICE0_IP &>/dev/null; then
    echo "✓ Can reach Device0!"
else
    echo "⚠ Cannot reach Device0 yet (may take a moment for mesh to form)"
    echo "  Try: ping 192.168.99.100"
fi

################################################################################
# Update field-client Service (if exists)
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Checking field-client Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f /etc/systemd/system/field-client.service ]; then
    echo "✓ field-client service exists"

    # Check if it has proper dependency
    if grep -q "Requires=batman-mesh-client.service" /etc/systemd/system/field-client.service; then
        echo "✓ field-client has mesh dependency"
    else
        echo "⚠ field-client may be missing mesh dependency"
        echo "  Checking service file..."
        cat /etc/systemd/system/field-client.service
    fi

    # Restart field-client if it's enabled
    if systemctl is-enabled field-client.service &>/dev/null; then
        echo ""
        echo "Restarting field-client service..."
        sudo systemctl restart field-client.service
        sleep 2

        if systemctl is-active field-client.service &>/dev/null; then
            echo "✓ field-client service is running"
        else
            echo "⚠ field-client service not running"
            echo "  Check: sudo journalctl -u field-client -n 20"
        fi
    fi
else
    echo "ℹ field-client service not installed yet (install with Phase 5)"
fi

################################################################################
# Summary
################################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fix Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What was fixed:"
echo "  ✓ Service file updated with better networking dependencies"
echo "  ✓ Service enabled for auto-start on boot"
echo "  ✓ Service started immediately"
echo "  ✓ Auto-restart on failure configured"
echo ""
echo "Next Steps:"
echo "  1. Test reboot: sudo reboot"
echo "  2. After reboot, check: sudo systemctl status batman-mesh-client"
echo "  3. Verify connectivity: ping 192.168.99.100"
echo "  4. Check Device0 web interface for this device"
echo ""
echo "To see detailed status at any time:"
echo "  sudo systemctl status batman-mesh-client"
echo "  sudo batctl n"
echo "  ip addr show bat0"
echo ""

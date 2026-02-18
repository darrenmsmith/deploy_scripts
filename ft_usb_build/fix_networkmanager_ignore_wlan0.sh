#!/bin/bash

################################################################################
# Fix NetworkManager - Mark wlan0 as Unmanaged
# Prevents NetworkManager from resetting wlan0 to managed mode
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Fixing NetworkManager - Set wlan0 as Unmanaged"
echo "════════════════════════════════════════════════════════════"
echo ""

# Create NetworkManager conf.d directory if it doesn't exist
sudo mkdir -p /etc/NetworkManager/conf.d

# Create configuration file to mark wlan0 as unmanaged
CONF_FILE="/etc/NetworkManager/conf.d/99-unmanage-wlan0.conf"

echo "Creating NetworkManager configuration: $CONF_FILE"
echo ""

sudo tee "$CONF_FILE" > /dev/null << 'EOF'
[keyfile]
unmanaged-devices=interface-name:wlan0;interface-name:bat0

[device]
wifi.scan-rand-mac-address=no
EOF

echo "✓ Configuration file created"
echo ""

echo "Contents:"
cat "$CONF_FILE"
echo ""

echo "Restarting NetworkManager..."
sudo systemctl restart NetworkManager.service
echo "✓ NetworkManager restarted"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Verification"
echo "════════════════════════════════════════════════════════════"
echo ""

sleep 2

echo "NetworkManager device status:"
nmcli device status 2>/dev/null || echo "nmcli not available"
echo ""

echo "wlan0 should show as 'unmanaged'"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Fix complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "NetworkManager will now ignore wlan0 and bat0"
echo ""
echo "To test:"
echo "  sudo systemctl restart batman-mesh-client.service"
echo "  iw dev wlan0 info | grep type    # Should show IBSS"
echo "  sleep 30"
echo "  iw dev wlan0 info | grep type    # Should STILL be IBSS"
echo ""
echo "Then test with reboot:"
echo "  sudo reboot"
echo ""
echo "After reboot:"
echo "  iw dev wlan0 info | grep type    # Should be IBSS"
echo "  nmcli device status               # wlan0 should show 'unmanaged'"
echo "  sudo batctl n                      # Should show neighbors"
echo ""

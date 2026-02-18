#!/bin/bash

################################################################################
# Fix dhcpcd - Prevent it from Managing wlan0
# wlan0 is for batman-adv mesh, NOT for dhcpcd to manage
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Fixing dhcpcd Configuration - Ignore wlan0"
echo "════════════════════════════════════════════════════════════"
echo ""

DHCPCD_CONF="/etc/dhcpcd.conf"

if [ ! -f "$DHCPCD_CONF" ]; then
    echo "✗ ERROR: dhcpcd.conf not found at $DHCPCD_CONF"
    exit 1
fi

echo "Found dhcpcd.conf: $DHCPCD_CONF"
echo ""

# Backup
BACKUP_FILE="${DHCPCD_CONF}.backup_wlan0_ignore_$(date +%Y%m%d_%H%M%S)"
sudo cp "$DHCPCD_CONF" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Check if wlan0 is already in denyinterfaces
if grep -q "^denyinterfaces.*wlan0" "$DHCPCD_CONF"; then
    echo "✓ wlan0 already in denyinterfaces"
    echo ""
else
    echo "Adding wlan0 to denyinterfaces..."

    # Add denyinterfaces line at the top (after any existing denyinterfaces)
    if grep -q "^denyinterfaces" "$DHCPCD_CONF"; then
        # Append wlan0 to existing denyinterfaces line
        sudo sed -i 's/^denyinterfaces\(.*\)/denyinterfaces\1 wlan0/' "$DHCPCD_CONF"
    else
        # Add new denyinterfaces line at top
        sudo sed -i '1i # Ignore wlan0 - managed by batman-adv mesh\ndenyinterfaces wlan0\n' "$DHCPCD_CONF"
    fi

    echo "✓ Added wlan0 to denyinterfaces"
    echo ""
fi

# Also make sure bat0 is in denyinterfaces (it's a virtual mesh interface)
if grep -q "^denyinterfaces.*bat0" "$DHCPCD_CONF"; then
    echo "✓ bat0 already in denyinterfaces"
else
    echo "Adding bat0 to denyinterfaces..."
    sudo sed -i 's/^denyinterfaces\(.*\)/denyinterfaces\1 bat0/' "$DHCPCD_CONF"
    echo "✓ Added bat0 to denyinterfaces"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Current dhcpcd Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""
grep "^denyinterfaces" "$DHCPCD_CONF" || echo "No denyinterfaces line found"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Fix complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "dhcpcd will now ignore wlan0 and bat0"
echo ""
echo "Restarting dhcpcd service..."
sudo systemctl restart dhcpcd.service 2>/dev/null || echo "dhcpcd not running as service"
echo ""
echo "To test:"
echo "  sudo systemctl restart batman-mesh-client.service"
echo "  iw dev wlan0 info | grep type    # Should stay IBSS"
echo "  sleep 10"
echo "  iw dev wlan0 info | grep type    # Should still be IBSS"
echo ""
echo "Then test with reboot:"
echo "  sudo reboot"
echo ""

#!/bin/bash

################################################################################
# Fix Client Mesh Startup - Robust RF-kill Unblock
# Uses multiple methods to ensure phy0 stays unblocked
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Fixing Client Mesh Startup - Robust RF-kill"
echo "════════════════════════════════════════════════════════════"
echo ""

STARTUP_SCRIPT="/usr/local/bin/start-batman-mesh-client.sh"

# Check if startup script exists
if [ ! -f "$STARTUP_SCRIPT" ]; then
    echo "✗ ERROR: Startup script not found: $STARTUP_SCRIPT"
    exit 1
fi

echo "Found startup script: $STARTUP_SCRIPT"
echo ""

# Create backup
BACKUP_FILE="${STARTUP_SCRIPT}.backup_robust_$(date +%Y%m%d_%H%M%S)"
sudo cp "$STARTUP_SCRIPT" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Remove any existing rfkill lines
echo "Removing old rfkill unblock lines..."
sudo sed -i '/^rfkill unblock/d' "$STARTUP_SCRIPT"
sudo sed -i '/# Unblock/d' "$STARTUP_SCRIPT"
sudo sed -i '/^sleep 1$/d' "$STARTUP_SCRIPT"
echo "✓ Removed old lines"
echo ""

# Add robust rfkill unblock - right after modprobe
echo "Adding robust RF-kill unblock..."
sudo sed -i '/^modprobe batman-adv$/a\
\
# Unblock WiFi RF-kill (multiple methods for reliability)\
rfkill unblock all\
sleep 1\
rfkill unblock 0 2>/dev/null || true\
rfkill unblock wifi' "$STARTUP_SCRIPT"

echo "✓ Added robust RF-kill unblock"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Verification"
echo "════════════════════════════════════════════════════════════"
echo ""
grep -A 8 "modprobe batman-adv" "$STARTUP_SCRIPT"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Fix complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "To test:"
echo "  sudo systemctl restart batman-mesh-client.service"
echo "  rfkill list           # Check phy0 is unblocked"
echo "  iw dev wlan0 info     # Check type is IBSS"
echo "  sudo batctl n         # Check for neighbors"
echo ""
echo "Then test with reboot:"
echo "  sudo reboot"
echo ""

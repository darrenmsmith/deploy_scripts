#!/bin/bash

################################################################################
# Fix Service Boot Timing - Add Delay for WiFi Driver Initialization
# Ensures service waits for WiFi subsystem to be fully ready
################################################################################

echo "════════════════════════════════════════════════════════════"
echo "  Fixing Service Boot Timing"
echo "════════════════════════════════════════════════════════════"
echo ""

SERVICE_FILE="/etc/systemd/system/batman-mesh-client.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "✗ ERROR: Service file not found: $SERVICE_FILE"
    exit 1
fi

echo "Found service file: $SERVICE_FILE"
echo ""

# Backup
BACKUP_FILE="${SERVICE_FILE}.backup_timing_$(date +%Y%m%d_%H%M%S)"
sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

echo "Updating service with boot delay..."
echo ""

# Create new service file with boot delay
sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=BATMAN-adv Mesh Network (Client)
After=network.target network-online.target sys-subsystem-net-devices-wlan0.device
Wants=network-online.target
Before=field-client.service

[Service]
Type=oneshot
RemainAfterExit=yes
# Wait for WiFi subsystem to be fully initialized
ExecStartPre=/bin/sleep 10
# Wait for wlan0 to actually exist
ExecStartPre=/bin/bash -c 'for i in {1..30}; do [ -e /sys/class/net/wlan0 ] && break || sleep 1; done'
ExecStart=/usr/local/bin/start-batman-mesh-client.sh
ExecStop=/usr/local/bin/stop-batman-mesh-client.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file updated"
echo ""

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
echo "✓ Daemon reloaded"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Service Configuration"
echo "════════════════════════════════════════════════════════════"
echo ""
cat "$SERVICE_FILE"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "✓ Fix complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Changes made:"
echo "  ✓ Added 10-second delay before service starts"
echo "  ✓ Added dependency on wlan0 device"
echo "  ✓ Added check to wait for /sys/class/net/wlan0 (up to 30s)"
echo "  ✓ Service waits for network-online.target"
echo ""
echo "This ensures WiFi driver is fully loaded before mesh setup runs"
echo ""
echo "To test:"
echo "  sudo systemctl restart batman-mesh-client.service"
echo "  # Should still work"
echo ""
echo "Then test with reboot (THE CRITICAL TEST):"
echo "  sudo reboot"
echo ""
echo "After reboot, verify:"
echo "  iw dev wlan0 info | grep type    # Should show IBSS"
echo "  sudo batctl n                     # Should show neighbors"
echo "  sudo journalctl -u batman-mesh-client.service -b   # Check for errors"
echo ""

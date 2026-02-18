#!/bin/bash

################################################################################
# Diagnose Mesh Boot Issues
# Compare startup script, service status, and current state
################################################################################

OUTPUT_FILE="/tmp/boot_mesh_diagnostic_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

# If USB is mounted, save there instead
if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/boot_mesh_diagnostic_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Mesh Boot Diagnostic - $(hostname)"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Startup Script Contents"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "File: /usr/local/bin/start-batman-mesh-client.sh"
    echo ""
    cat /usr/local/bin/start-batman-mesh-client.sh
    echo ""

    # Check if rfkill unblock is present
    if grep -q "rfkill unblock" /usr/local/bin/start-batman-mesh-client.sh; then
        echo "✓ RF-kill unblock FOUND in startup script"
    else
        echo "✗ RF-kill unblock MISSING from startup script"
    fi
    echo ""
else
    echo "✗ Startup script NOT FOUND"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Current RF-kill Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
rfkill list
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Systemd Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
systemctl status batman-mesh-client.service --no-pager -l
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Service Logs from Current Boot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
journalctl -u batman-mesh-client.service -b --no-pager
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. wlan0 Interface Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "IP status:"
ip addr show wlan0 2>/dev/null || echo "wlan0 not found"
echo ""
echo "Wireless info:"
iw dev wlan0 info 2>/dev/null || echo "wlan0 wireless info unavailable"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. bat0 Interface Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ip addr show bat0 2>/dev/null || echo "bat0 not found"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Batman-adv Interfaces"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sudo batctl if 2>/dev/null || echo "No batman-adv interfaces"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. Batman-adv Neighbors"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sudo batctl n 2>/dev/null || echo "batctl not available"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. Connectivity Test to Device0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ping -c 3 -W 2 192.168.99.100 || echo "Cannot reach Device0"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. Recent System Messages (mesh/wlan related)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
dmesg | grep -i "wlan0\|batman\|mesh\|rf-kill\|rfkill" | tail -50
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Diagnostic Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""

if [ -d "/mnt/usb/ft_usb_build" ]; then
    echo "Log saved to USB drive - unmount and move to Device0 for analysis"
else
    echo "To copy log to Device0 USB drive:"
    echo "  scp $OUTPUT_FILE pi@192.168.99.100:/mnt/usb/ft_usb_build/"
fi
echo ""

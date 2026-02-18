#!/bin/bash

################################################################################
# Capture Client Mesh Status
# Run this on a client device (Device1-5) to capture complete mesh status
################################################################################

OUTPUT_DIR="/tmp"
OUTPUT_FILE="${OUTPUT_DIR}/client_mesh_status_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

echo "========================================"  | tee "$OUTPUT_FILE"
echo "Client Mesh Status Capture"              | tee -a "$OUTPUT_FILE"
echo "========================================"  | tee -a "$OUTPUT_FILE"
echo "Date: $(date)"                            | tee -a "$OUTPUT_FILE"
echo "Hostname: $(hostname)"                    | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 1. Check batman-mesh-client Service
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "1. batman-mesh-client Service Status"    | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

if [ -f /etc/systemd/system/batman-mesh-client.service ]; then
    echo "Service file EXISTS"                  | tee -a "$OUTPUT_FILE"
    systemctl status batman-mesh-client.service --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ Service file MISSING"               | tee -a "$OUTPUT_FILE"
    echo "  Expected: /etc/systemd/system/batman-mesh-client.service" | tee -a "$OUTPUT_FILE"
fi
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Service Enabled:"                         | tee -a "$OUTPUT_FILE"
systemctl is-enabled batman-mesh-client.service 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Service Active:"                          | tee -a "$OUTPUT_FILE"
systemctl is-active batman-mesh-client.service 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 2. Check Service Logs
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "2. Recent Service Logs"                  | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Last 50 lines from batman-mesh-client:"  | tee -a "$OUTPUT_FILE"
sudo journalctl -u batman-mesh-client -n 50 --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Boot logs for batman-mesh-client:"        | tee -a "$OUTPUT_FILE"
sudo journalctl -u batman-mesh-client -b --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "All logs since service creation:"         | tee -a "$OUTPUT_FILE"
sudo journalctl -u batman-mesh-client --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 3. Check wlan0 Interface
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "3. wlan0 Interface Status"               | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "ip link show wlan0:"                      | tee -a "$OUTPUT_FILE"
ip link show wlan0 2>&1                         | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "ip addr show wlan0:"                      | tee -a "$OUTPUT_FILE"
ip addr show wlan0 2>&1                         | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "iw dev wlan0 info:"                       | tee -a "$OUTPUT_FILE"
iw dev wlan0 info 2>&1                          | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "iwconfig wlan0:"                          | tee -a "$OUTPUT_FILE"
iwconfig wlan0 2>&1                             | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 4. Check bat0 Interface
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "4. bat0 Interface Status"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

if ip link show bat0 &>/dev/null; then
    echo "bat0 interface EXISTS"                | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "ip link show bat0:"                   | tee -a "$OUTPUT_FILE"
    ip link show bat0 2>&1                      | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "ip addr show bat0:"                   | tee -a "$OUTPUT_FILE"
    ip addr show bat0 2>&1                      | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"
else
    echo "✗ bat0 interface MISSING"            | tee -a "$OUTPUT_FILE"
    echo "  This means batman-adv is not active" | tee -a "$OUTPUT_FILE"
fi
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 5. Check BATMAN-adv Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "5. BATMAN-adv Status"                    | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "lsmod | grep batman:"                     | tee -a "$OUTPUT_FILE"
lsmod | grep batman 2>&1                        | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "batctl -v:"                               | tee -a "$OUTPUT_FILE"
batctl -v 2>&1                                  | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "batctl if:"                               | tee -a "$OUTPUT_FILE"
sudo batctl if 2>&1                             | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "batctl n (neighbors):"                    | tee -a "$OUTPUT_FILE"
sudo batctl n 2>&1                              | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "batctl o (originators):"                  | tee -a "$OUTPUT_FILE"
sudo batctl o 2>&1                              | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 6. Check Startup Script
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "6. Startup Script Contents"              | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

if [ -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "Startup script EXISTS"               | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "/usr/local/bin/start-batman-mesh-client.sh:" | tee -a "$OUTPUT_FILE"
    cat /usr/local/bin/start-batman-mesh-client.sh 2>&1 | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "Script executable:"                   | tee -a "$OUTPUT_FILE"
    ls -l /usr/local/bin/start-batman-mesh-client.sh 2>&1 | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"
else
    echo "✗ Startup script MISSING"            | tee -a "$OUTPUT_FILE"
    echo "  Expected: /usr/local/bin/start-batman-mesh-client.sh" | tee -a "$OUTPUT_FILE"
fi
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 7. Check Service File
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "7. Service File Contents"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

if [ -f /etc/systemd/system/batman-mesh-client.service ]; then
    echo "/etc/systemd/system/batman-mesh-client.service:" | tee -a "$OUTPUT_FILE"
    cat /etc/systemd/system/batman-mesh-client.service 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ Service file MISSING"             | tee -a "$OUTPUT_FILE"
fi
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 8. Test Manual Startup Script Execution
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "8. Test Manual Script Execution"         | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

if [ -f /usr/local/bin/start-batman-mesh-client.sh ]; then
    echo "Attempting to run startup script manually..." | tee -a "$OUTPUT_FILE"
    echo "(This will show if script has syntax errors)" | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    sudo bash -x /usr/local/bin/start-batman-mesh-client.sh 2>&1 | tee -a "$OUTPUT_FILE"

    echo ""                                     | tee -a "$OUTPUT_FILE"
    echo "Manual execution complete"            | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    # Check status after manual run
    echo "Status after manual run:"             | tee -a "$OUTPUT_FILE"
    echo "wlan0 mode:"                          | tee -a "$OUTPUT_FILE"
    iw dev wlan0 info 2>&1 | grep -E "type|ssid" | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "bat0 status:"                         | tee -a "$OUTPUT_FILE"
    ip addr show bat0 2>&1 | grep -E "state|inet" | tee -a "$OUTPUT_FILE"
    echo ""                                     | tee -a "$OUTPUT_FILE"

    echo "batctl neighbors:"                    | tee -a "$OUTPUT_FILE"
    sudo batctl n 2>&1                          | tee -a "$OUTPUT_FILE"
fi
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 9. Check Network Configuration
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "9. Network Configuration"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "All network interfaces:"                  | tee -a "$OUTPUT_FILE"
ip addr show 2>&1                               | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Routing table:"                           | tee -a "$OUTPUT_FILE"
ip route 2>&1                                   | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 10. Check rfkill Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "10. rfkill Status"                        | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

sudo rfkill list 2>&1                           | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 11. Check dmesg for Errors
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "11. Recent dmesg Errors"                 | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "dmesg | grep -i batman:"                  | tee -a "$OUTPUT_FILE"
dmesg | grep -i batman | tail -50 2>&1          | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "dmesg | grep -i wlan:"                    | tee -a "$OUTPUT_FILE"
dmesg | grep -i wlan | tail -50 2>&1            | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "dmesg | grep -i error:"                   | tee -a "$OUTPUT_FILE"
dmesg | grep -i error | tail -50 2>&1           | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 12. Test Connectivity to Device0
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "12. Connectivity Test"                   | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

DEVICE0_IP="192.168.99.100"

echo "Ping test to Device0 ($DEVICE0_IP):"     | tee -a "$OUTPUT_FILE"
ping -c 5 -W 5 $DEVICE0_IP 2>&1                 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# Summary
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "Capture Complete"                         | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"            | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"
echo "Copy this file back to Device0 USB drive:" | tee -a "$OUTPUT_FILE"
echo "  scp $OUTPUT_FILE pi@192.168.99.100:/mnt/usb/ft_usb_build/" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

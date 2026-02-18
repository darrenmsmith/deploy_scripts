#!/bin/bash

################################################################################
# Capture Device0 Mesh Status
# Run this on Device0 to capture complete mesh configuration and status
################################################################################

OUTPUT_FILE="/mnt/usb/ft_usb_build/device0_mesh_status_$(date +%Y%m%d_%H%M%S).log"

echo "========================================"  | tee "$OUTPUT_FILE"
echo "Device0 Mesh Status Capture"              | tee -a "$OUTPUT_FILE"
echo "========================================"  | tee -a "$OUTPUT_FILE"
echo "Date: $(date)"                            | tee -a "$OUTPUT_FILE"
echo "Hostname: $(hostname)"                    | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 1. Check batman-mesh Service
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "1. batman-mesh Service Status"           | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

systemctl status batman-mesh.service --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Service Enabled:"                         | tee -a "$OUTPUT_FILE"
systemctl is-enabled batman-mesh.service 2>&1  | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Service Active:"                          | tee -a "$OUTPUT_FILE"
systemctl is-active batman-mesh.service 2>&1   | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 2. Check Service Logs
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "2. Recent Service Logs"                  | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Last 50 lines from batman-mesh service:" | tee -a "$OUTPUT_FILE"
sudo journalctl -u batman-mesh -n 50 --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Boot logs for batman-mesh:"               | tee -a "$OUTPUT_FILE"
sudo journalctl -u batman-mesh -b --no-pager 2>&1 | tee -a "$OUTPUT_FILE"
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

echo "iw dev wlan0 scan dump (if available):"   | tee -a "$OUTPUT_FILE"
sudo iw dev wlan0 scan dump 2>&1 | head -50     | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 4. Check bat0 Interface
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "4. bat0 Interface Status"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "ip link show bat0:"                       | tee -a "$OUTPUT_FILE"
ip link show bat0 2>&1                          | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "ip addr show bat0:"                       | tee -a "$OUTPUT_FILE"
ip addr show bat0 2>&1                          | tee -a "$OUTPUT_FILE"
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

echo "batctl gw (gateway mode):"                | tee -a "$OUTPUT_FILE"
sudo batctl gw 2>&1                             | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 6. Check Startup Script
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "6. Startup Script Contents"              | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "/usr/local/bin/start-batman-mesh.sh:"    | tee -a "$OUTPUT_FILE"
cat /usr/local/bin/start-batman-mesh.sh 2>&1   | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Script executable:"                       | tee -a "$OUTPUT_FILE"
ls -l /usr/local/bin/start-batman-mesh.sh 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 7. Check Service File
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "7. Service File Contents"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "/etc/systemd/system/batman-mesh.service:" | tee -a "$OUTPUT_FILE"
cat /etc/systemd/system/batman-mesh.service 2>&1 | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 8. Check Network Configuration
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "8. Network Configuration"                | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "All network interfaces:"                  | tee -a "$OUTPUT_FILE"
ip addr show 2>&1                               | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

echo "Routing table:"                           | tee -a "$OUTPUT_FILE"
ip route 2>&1                                   | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 9. Check rfkill Status
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "9. rfkill Status"                         | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

sudo rfkill list 2>&1                           | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

################################################################################
# 10. Check dmesg for Errors
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "10. Recent dmesg Errors"                 | tee -a "$OUTPUT_FILE"
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
# Summary
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo "Capture Complete"                         | tee -a "$OUTPUT_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE"            | tee -a "$OUTPUT_FILE"
echo ""                                         | tee -a "$OUTPUT_FILE"

# Also save to timestamped file
cp "$OUTPUT_FILE" "/mnt/usb/ft_usb_build/device0_mesh_status_latest.log"
echo "Also saved to: /mnt/usb/ft_usb_build/device0_mesh_status_latest.log"
echo ""

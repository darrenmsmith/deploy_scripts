#!/bin/bash

################################################################################
# Device0 Neighbor Analysis
# Run this on Device0 to see detailed neighbor information
################################################################################

OUTPUT_FILE="/tmp/device0_neighbor_analysis_$(date +%Y%m%d_%H%M%S).log"

if [ -d "/mnt/usb/ft_usb_build" ]; then
    OUTPUT_FILE="/mnt/usb/ft_usb_build/device0_neighbor_analysis_$(date +%Y%m%d_%H%M%S).log"
fi

exec > >(tee "$OUTPUT_FILE") 2>&1

echo "════════════════════════════════════════════════════════════"
echo "  Device0 Neighbor Analysis"
echo "  Date: $(date)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. BATMAN-ADV NEIGHBORS (WITH FULL DETAILS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Neighbor list:"
sudo batctl n
echo ""
echo "Neighbor list with MAC addresses:"
sudo batctl n -H
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. KNOWN CLIENT MAC ADDRESSES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Device3 should be: (check /tmp/deploy_scripts logs or previous diagnostics)"
echo "Device4 MAC: b8:27:eb:a9:54:36 (from previous logs)"
echo "Device5 should be: b8:27:eb:61:4b:0e (from previous logs)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. IBSS STATIONS VISIBLE TO DEVICE0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
iw dev wlan0 station dump
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. ORIGINATORS (SHOWS ROUTES TO ALL MESH NODES)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sudo batctl o
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. GATEWAY CLIENT STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
sudo batctl gwl
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. CONTINUOUS MONITORING (30 seconds)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watching neighbor changes for 30 seconds..."
echo "Timestamp: $(date)"
echo ""

for i in {1..6}; do
    echo "--- Check $i ($(date +%H:%M:%S)) ---"
    sudo batctl n
    echo ""
    sleep 5
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. CONNECTIVITY TEST TO KNOWN CLIENT IPs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
for IP in 192.168.99.101 192.168.99.102 192.168.99.103 192.168.99.104 192.168.99.105; do
    echo "Pinging Device at $IP:"
    ping -c 2 -W 1 $IP 2>&1 || echo "  No response"
    echo ""
done

echo "════════════════════════════════════════════════════════════"
echo "  Analysis Complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Log saved to: $OUTPUT_FILE"
echo ""
